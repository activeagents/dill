class TechDiligenceAgent < ApplicationAgent
  has_context

  generate_with :openai,
    model: "gpt-4o",
    stream: true,
    api_version: :chat,  # Required for vision API
    instructions: <<~INSTRUCTIONS
      You are a technical due diligence expert analyzing documentation for technology assessments.
      Your specialty is extracting precise technical specifications from documents like manuals,
      datasheets, architecture diagrams, and technical documentation.

      CRITICAL: Always cite your sources with exact provenance:
      - Document name
      - Page number
      - Relevant text or description of visual element

      Format citations as: [Source: document_name, Page X]

      Be thorough, precise, and cite every claim you make.
    INSTRUCTIONS

  on_stream :broadcast_chunk
  on_stream_close :broadcast_complete

  # Answer specific questions about a document using both text and images
  def answer_questions
    @document = params[:document]
    @questions = params[:questions] || []
    @use_vision = params[:use_vision] != false

    validate_document!
    prepare_document_context

    create_context(
      contextable: @document,
      input_params: build_input_params("answer_questions")
    )

    # For vision analysis, pass a representative page image
    # ActiveAgent currently supports single image per prompt
    if @use_vision && @page_images.any?
      prompt image: @page_images.first
    else
      prompt
    end
  end

  # Analyze specific pages with vision for technical details
  def analyze_pages
    @document = params[:document]
    @page_numbers = params[:page_numbers] || (1..[@document.page_count, 10].min).to_a
    @focus_areas = params[:focus_areas] || []

    validate_document!
    prepare_pages_for_analysis

    create_context(
      contextable: @document,
      input_params: build_input_params("analyze_pages")
    )

    if @page_images.any?
      prompt image: @page_images.first
    else
      prompt
    end
  end

  # Extract technical specifications from a document
  def extract_specs
    @document = params[:document]
    @spec_categories = params[:spec_categories] || %w[cpu memory storage connectivity power]

    validate_document!
    prepare_document_context

    create_context(
      contextable: @document,
      input_params: build_input_params("extract_specs")
    )

    if @page_images.any?
      prompt image: @page_images.first
    else
      prompt
    end
  end

  # Compare document claims against a checklist
  def verify_claims
    @document = params[:document]
    @claims = params[:claims] || []

    validate_document!
    prepare_document_context

    create_context(
      contextable: @document,
      input_params: build_input_params("verify_claims")
    )

    if @page_images.any?
      prompt image: @page_images.first
    else
      prompt
    end
  end

  private

  def validate_document!
    raise ArgumentError, "Document is required" unless @document
    raise ArgumentError, "Document must be a Document model" unless @document.is_a?(Document)
  end

  def prepare_document_context
    @page_text_context = build_page_text_context
    @page_images = build_page_images if @use_vision
    @page_images ||= []

    Rails.logger.info "[TechDiligenceAgent] Prepared context: #{@document.page_count} pages, " \
                      "#{@page_images.size} images, #{@page_text_context.length} chars text"
  end

  def prepare_pages_for_analysis
    @page_text_context = @page_numbers.map do |n|
      text = @document.text_for_page(n)
      next unless text.present?

      "## Page #{n}\n#{text}"
    end.compact.join("\n\n---\n\n")

    @page_images = @page_numbers.filter_map do |n|
      @document.image_data_uri_for_page(n)
    end

    Rails.logger.info "[TechDiligenceAgent] Prepared #{@page_numbers.size} pages: " \
                      "#{@page_images.size} images loaded"
  end

  def build_page_text_context
    return "" unless @document.page_text.present?

    @document.page_text.map do |page_num, text|
      next if text.blank?

      "## Page #{page_num}\n#{text}"
    end.compact.join("\n\n---\n\n")
  end

  def build_page_images(max_pages: 20)
    return [] unless @document.has_page_images?

    # Prioritize pages that have less text (likely diagrams/tables)
    pages_to_image = select_pages_for_vision(max_pages)

    pages_to_image.filter_map do |page_num|
      data_uri = @document.image_data_uri_for_page(page_num)
      next unless data_uri

      Rails.logger.debug "[TechDiligenceAgent] Loaded image for page #{page_num}"
      data_uri
    end
  end

  # Select which pages to include as images (prioritize visual content)
  def select_pages_for_vision(max_pages)
    return [] unless @document.page_count

    page_scores = (1..@document.page_count).map do |n|
      text = @document.text_for_page(n) || ""
      text_length = text.length

      # Score pages: lower text = likely more visual content
      # Also boost certain page ranges (specs often near beginning/end)
      visual_score = if text_length < 100
        100  # Likely a diagram or image-heavy page
      elsif text_length < 500
        50   # Mixed content
      else
        10   # Text-heavy
      end

      # Boost first and last pages (often have key specs)
      position_boost = (n <= 5 || n >= @document.page_count - 5) ? 20 : 0

      { page: n, score: visual_score + position_boost }
    end

    # Sort by score and take top pages
    page_scores
      .sort_by { |p| -p[:score] }
      .take(max_pages)
      .map { |p| p[:page] }
      .sort  # Return in page order
  end

  def build_input_params(action)
    {
      action: action,
      document_id: @document.id,
      document_name: @document.file&.filename&.to_s,
      page_count: @document.page_count,
      pages_with_images: @page_images.size,
      questions: @questions,
      focus_areas: @focus_areas,
      spec_categories: @spec_categories,
      claims: @claims
    }.compact
  end

  def broadcast_chunk(chunk)
    return unless chunk.message
    return unless params[:stream_id]

    @accumulated_content ||= ""
    @accumulated_content = chunk.message[:content] if chunk.message[:content].present?

    ActionCable.server.broadcast(params[:stream_id], { content: chunk.message[:content] })
  end

  def broadcast_complete(chunk)
    return unless params[:stream_id]

    # Create fragments for provenance tracking
    create_answer_fragments if @accumulated_content.present?

    ActionCable.server.broadcast(params[:stream_id], {
      done: true,
      document_id: @document.id,
      pages_analyzed: @page_images.size
    })
  end

  # Parse accumulated content and create fragments with provenance
  def create_answer_fragments
    return unless context.present?

    # Parse citations from the response
    citations = extract_citations(@accumulated_content)

    citations.each do |citation|
      context.fragments.create!(
        contextable: @document,
        fragment_type: "citation",
        action_type: "document_analysis",
        generated_content: citation[:text],
        metadata: {
          page_number: citation[:page],
          source_document: @document.file&.filename&.to_s,
          confidence: citation[:confidence]
        },
        status: "generated"
      )
    end

    Rails.logger.info "[TechDiligenceAgent] Created #{citations.size} citation fragments"
  rescue => e
    Rails.logger.warn "[TechDiligenceAgent] Failed to create fragments: #{e.message}"
  end

  # Extract structured citations from response text
  def extract_citations(text)
    citations = []

    # Match patterns like [Source: document_name, Page X] or (Page X)
    text.scan(/\[Source:\s*([^,\]]+),\s*Page\s*(\d+)\]/i) do |doc, page|
      # Find the preceding sentence/claim
      match_pos = $~.begin(0)
      preceding_text = text[0...match_pos]
      claim = preceding_text.split(/[.!?]/).last&.strip

      citations << {
        text: claim,
        page: page.to_i,
        document: doc.strip,
        confidence: 0.9
      }
    end

    # Also match simpler (Page X) references
    text.scan(/\(Page\s*(\d+)\)/i) do |page|
      match_pos = $~.begin(0)
      preceding_text = text[0...match_pos]
      claim = preceding_text.split(/[.!?]/).last&.strip

      citations << {
        text: claim,
        page: page[0].to_i,
        document: @document.file&.filename&.to_s,
        confidence: 0.8
      }
    end

    citations.uniq { |c| [c[:text], c[:page]] }
  end
end
