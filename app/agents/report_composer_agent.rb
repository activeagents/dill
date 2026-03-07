class ReportComposerAgent < ApplicationAgent
  has_context

  generate_with :openai,
    model: "gpt-4o",
    stream: true,
    instructions: <<~INSTRUCTIONS
      You are an expert report writer composing due diligence sections from source documents.

      CRITICAL REQUIREMENTS:
      1. Always cite your sources with exact provenance: [Source: document_name, Page X]
      2. Only include information that can be verified from the provided documents
      3. Structure your response with clear headings and bullet points
      4. Highlight any gaps or areas needing further investigation
      5. Be precise, thorough, and objective
    INSTRUCTIONS

  on_stream :broadcast_chunk
  on_stream_close :broadcast_complete

  # Compose a new section from a topic/question using document context
  def compose
    @report = params[:report]
    @topic = params[:topic]
    @section_type = params[:section_type] || "analysis"
    @focus_documents = params[:document_ids]

    validate_params!
    gather_document_context

    create_context(
      contextable: @report,
      input_params: build_input_params
    )

    prompt
  end

  # Generate content for an existing section using document references
  def generate_section
    @section = params[:section]
    @prompt_text = params[:prompt]
    @use_related = params[:use_related] != false

    validate_section!
    gather_section_context

    create_context(
      contextable: @section.sectionable,
      input_params: build_input_params
    )

    prompt
  end

  # Answer a specific question using all available document context
  def answer_question
    @report = params[:report]
    @question = params[:question]
    @focus_documents = params[:document_ids]

    validate_params!
    gather_document_context

    create_context(
      contextable: @report,
      input_params: build_input_params
    )

    prompt
  end

  private

  def validate_params!
    raise ArgumentError, "Report is required" unless @report
    raise ArgumentError, "Topic or question is required" unless @topic.present? || @question.present?
  end

  def validate_section!
    raise ArgumentError, "Section is required" unless @section
  end

  def gather_document_context
    @documents = if @focus_documents.present?
      @report.documents.where(id: @focus_documents).where.not(page_text: nil)
    else
      @report.documents.where.not(page_text: nil)
    end

    @document_contexts = @documents.map do |doc|
      {
        document: doc,
        name: doc.file&.filename&.to_s,
        page_count: doc.page_count,
        relevant_pages: search_relevant_pages(doc)
      }
    end

    Rails.logger.info "[ReportComposerAgent] Gathered context from #{@documents.count} documents"
  end

  def gather_section_context
    @report = @section.report
    gather_document_context

    if @use_related && @section.sectionable.respond_to?(:section)
      @related_content = @section.sectionable.section.related_context(limit: 3, query: @prompt_text)
    end
  end

  # Search document pages for content relevant to the topic/question
  def search_relevant_pages(document)
    query = @topic || @question
    return [] unless query.present? && document.page_text.present?

    relevant = []
    query_terms = query.downcase.split(/\s+/).reject { |t| t.length < 3 }

    document.page_text.each do |page_num, text|
      next if text.blank?

      text_lower = text.downcase
      relevance_score = query_terms.count { |term| text_lower.include?(term) }

      if relevance_score > 0
        relevant << {
          page: page_num.to_i,
          score: relevance_score,
          excerpt: extract_relevant_excerpt(text, query_terms)
        }
      end
    end

    # Return top 10 most relevant pages
    relevant.sort_by { |p| -p[:score] }.take(10)
  end

  def extract_relevant_excerpt(text, query_terms, max_length: 500)
    # Find the first occurrence of any query term
    text_lower = text.downcase
    first_match_pos = query_terms.map { |t| text_lower.index(t) }.compact.min

    return text[0..max_length] unless first_match_pos

    # Extract context around the match
    start_pos = [first_match_pos - 100, 0].max
    end_pos = [first_match_pos + max_length, text.length].min

    excerpt = text[start_pos..end_pos]
    excerpt = "..." + excerpt if start_pos > 0
    excerpt = excerpt + "..." if end_pos < text.length
    excerpt
  end

  def build_input_params
    {
      topic: @topic,
      question: @question,
      section_type: @section_type,
      prompt: @prompt_text,
      document_count: @documents&.count || 0,
      document_names: @documents&.map { |d| d.file&.filename&.to_s },
      total_relevant_pages: @document_contexts&.sum { |ctx| ctx[:relevant_pages].size } || 0
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

    # Create fragments for citation tracking
    create_citation_fragments if @accumulated_content.present?

    ActionCable.server.broadcast(params[:stream_id], {
      done: true,
      citations_found: @citations_count || 0
    })
  end

  def create_citation_fragments
    return unless context.present?

    @citations_count = 0

    # Parse citations from the response
    @accumulated_content.scan(/\[Source:\s*([^,\]]+),\s*Page\s*(\d+)\]/i) do |doc_name, page_num|
      match_pos = $~.begin(0)
      preceding_text = @accumulated_content[0...match_pos]
      claim = preceding_text.split(/[.!?]/).last&.strip

      # Find the document by name
      document = @documents&.find { |d| d.file&.filename&.to_s&.include?(doc_name.strip) }

      context.fragments.create!(
        contextable: @report || @section&.sectionable,
        fragment_type: "citation",
        action_type: "report_composition",
        generated_content: claim,
        metadata: {
          page_number: page_num.to_i,
          source_document: doc_name.strip,
          document_id: document&.id,
          confidence: 0.9
        },
        status: "generated"
      )

      @citations_count += 1
    end

    Rails.logger.info "[ReportComposerAgent] Created #{@citations_count} citation fragments"
  rescue => e
    Rails.logger.warn "[ReportComposerAgent] Failed to create fragments: #{e.message}"
  end
end
