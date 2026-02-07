class ContentAnnotationService
  MIN_PHRASE_LENGTH = 12

  def initialize(page, report:)
    @page = page
    @report = report
    @outlines = report.sources.outlines.processed
    @outline_phrases = extract_outline_phrases
  end

  def annotate(html_content)
    return html_content if @outlines.empty?

    doc = Nokogiri::HTML.fragment(html_content)

    # Phase 1: Annotate text nodes that match outline content (blue)
    # Phase 2: Mark remaining unannotated text as AI-generated (purple)
    annotate_text_nodes(doc)

    doc.to_html
  end

  private

  def extract_outline_phrases
    @outlines.flat_map do |outline|
      content = outline.extracted_content
      next [] if content.blank?

      # Extract sentences and meaningful phrases from outline
      sentences = content.split(/[.!?\n]+/).map(&:strip).reject(&:blank?)

      # Also extract bullet points / key phrases
      bullets = content.scan(/[-*]\s*(.+)/).flatten.map(&:strip)

      (sentences + bullets)
        .reject { |p| p.length < MIN_PHRASE_LENGTH }
        .map { |p| normalize(p) }
        .uniq
    end
  end

  def normalize(text)
    text.downcase.gsub(/\s+/, " ").strip
  end

  def annotate_text_nodes(doc)
    # Collect all text nodes first to avoid modifying while traversing
    text_nodes = []
    doc.traverse do |node|
      next unless node.text?
      next if node.parent.name.in?(%w[mark del ins script style code pre])
      next if node.text.strip.blank?
      text_nodes << node
    end

    text_nodes.each do |node|
      annotate_single_text_node(node)
    end
  end

  def annotate_single_text_node(node)
    text = node.text
    normalized = normalize(text)

    # Check if this text matches any outline phrase
    matched = @outline_phrases.any? { |phrase| phrase_matches?(normalized, phrase) }

    # Check if this text was from an outline-referenced fragment
    fragment_match = check_fragment_origin(text)

    if matched || fragment_match == :outline
      wrap_node(node, "outline-ref", "outline")
    elsif fragment_match == :ai
      wrap_node(node, "ai-generated", "ai")
    else
      wrap_node(node, "ai-generated", "ai")
    end
  end

  def phrase_matches?(text, phrase)
    return false if text.length < MIN_PHRASE_LENGTH
    return false if phrase.length < MIN_PHRASE_LENGTH

    # Check if the outline phrase appears as a substring
    text.include?(phrase) || phrase.include?(text)
  end

  def check_fragment_origin(text)
    return nil if text.strip.length < MIN_PHRASE_LENGTH

    normalized_text = normalize(text)

    # Check applied fragments for this page
    fragments = @page.respond_to?(:direct_agent_fragments) ?
      @page.direct_agent_fragments.where(status: [:applied, :generated]) : []

    fragments.each do |fragment|
      content = fragment.applied_content.presence || fragment.generated_content
      next unless content.present?

      normalized_content = normalize(content)
      next unless normalized_content.include?(normalized_text) || normalized_text.include?(normalized_content.first(100))

      return fragment.outline_source_id.present? ? :outline : :ai
    end

    nil
  end

  def wrap_node(node, type_class, origin)
    mark = Nokogiri::XML::Node.new("mark", node.document)
    mark["class"] = "content-origin content-origin--#{type_class}"
    mark["data-origin"] = origin
    mark.content = node.text
    node.replace(mark)
  end
end
