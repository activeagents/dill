module PagesHelper
  def word_count(content)
    return if content.blank?
    pluralize number_with_delimiter(content.split.size), "word"
  end

  def page_title(section, report)
    [ section.title, report.title, report.author ].reject(&:blank?).to_sentence(two_words_connector: " · ", words_connector: " · ", last_word_connector: " · ")
  end

  def sanitize_content(content)
    sanitize content, scrubber: HtmlScrubber.new
  end

  def annotate_page_content(page, report)
    html = sanitize_content(page.body.to_html)

    # Apply outline-reference highlighting (blue/purple)
    if report.sources.outlines.processed.any?
      html = ContentAnnotationService.new(page, report: report).annotate(html)
    end

    # Apply diff recommendations (red/green)
    if page.respond_to?(:has_pending_suggestions?) && page.has_pending_suggestions?
      html = DiffAnnotationService.new(page).annotate(html)
    end

    html.html_safe
  end
end
