class DiffAnnotationService
  def initialize(page)
    @page = page
    @suggestions = page.respond_to?(:suggestions) ?
      page.suggestions.pending.where(ai_generated: true).order(created_at: :desc) : []
  end

  def annotate(html_content)
    return html_content if @suggestions.empty?

    doc = Nokogiri::HTML.fragment(html_content)

    @suggestions.each do |suggestion|
      next unless suggestion.suggestion_type == "edit" && suggestion.original_text.present?
      apply_diff_annotation(doc, suggestion)
    end

    doc.to_html
  end

  private

  def apply_diff_annotation(doc, suggestion)
    original = suggestion.original_text

    # Find and replace the first matching text node
    doc.traverse do |node|
      next unless node.text?
      next unless node.text.include?(original)

      diff_html = build_diff_html(suggestion)

      # Split the text node around the match
      before, match_and_after = node.text.split(original, 2)
      return unless match_and_after # safety check

      replacement = Nokogiri::HTML.fragment("")

      # Add text before the match
      replacement.add_child(Nokogiri::XML::Text.new(before, node.document)) if before.present?

      # Add the diff markup
      replacement.add_child(Nokogiri::HTML.fragment(diff_html))

      # Add text after the match
      replacement.add_child(Nokogiri::XML::Text.new(match_and_after, node.document)) if match_and_after.present?

      node.replace(replacement)
      return # Only replace the first occurrence
    end
  end

  def build_diff_html(suggestion)
    reason = escape_attr(suggestion.reasoning || suggestion.comment || "AI recommendation")
    suggestion_id = suggestion.id
    original_escaped = escape_html(suggestion.original_text)
    suggested_escaped = escape_html(suggestion.suggested_text)

    <<~HTML
      <span class="diff-recommendation" data-suggestion-id="#{suggestion_id}" data-reason="#{reason}"><del class="diff-remove">#{original_escaped}</del><ins class="diff-add">#{suggested_escaped}</ins></span>
    HTML
  end

  def escape_html(text)
    ERB::Util.html_escape(text)
  end

  def escape_attr(text)
    ERB::Util.html_escape(text.to_s.truncate(500))
  end
end
