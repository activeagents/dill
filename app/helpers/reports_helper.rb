module ReportsHelper
  def report_toc_tag(report, &)
    tag.ol class: "toc", tabindex: 0,
      data: {
        controller: "arrangement",
        action: arrangement_actions,
        arrangement_cursor_class: "arrangement-cursor",
        arrangement_selected_class: "arrangement-selected",
        arrangement_placeholder_class: "arrangement-placeholder",
        arrangement_move_mode_class: "arrangement-move-mode",
        arrangement_url_value: report_sections_moves_url(report)
      }, &
  end

  def report_part_create_button(report, kind, **, &)
    url = url_for [ report, kind.new ]

    button_to url, class: "btn btn--plain txt-medium fill-transparent disable-when-arranging disable-when-deleting", draggable: true,
      data: {
        action: "dragstart->arrangement#dragStartCreate dragend->arrangement#dragEndCreate",
        arrangement_url_param: url
      }, **, &
  end

  def link_to_first_sectionable(sections)
    if first_section = sections.first
      link_to sectionable_slug_path(first_section), data: hotkey_data_attributes("right"), class: "disable-when-arranging", hidden: true do
        tag.span(class: "btn") do
          image_tag("arrow-right.svg", aria: { hidden: true }, size: 24) + tag.span("Start reading", class: "for-screen-reader")
        end + tag.span(first_section.title, class: "overflow-ellipsis")
      end
    end
  end

  def link_to_previous_sectionable(section, hotkey: true, for_edit: false)
    if previous_section = section.previous
      path = for_edit ? edit_sectionable_path(previous_section) : sectionable_slug_path(previous_section)
      link_to path, data: hotkey_data_attributes("left", enabled: hotkey), class: "btn" do
        image_tag("arrow-left.svg", aria: { hidden: true }, size: 24) + tag.span("Previous: #{ previous_section.title }", class: "for-screen-reader")
      end
    else
      link_to report_slug_path(section.report), data: hotkey_data_attributes("left", enabled: hotkey), class: "btn" do
        image_tag("arrow-left.svg", aria: { hidden: true }, size: 24) + tag.span("Table of contents: #{ section.report.title }", class: "for-screen-reader")
      end
    end
  end

  def link_to_next_sectionable(section, hotkey: true, for_edit: false)
    if next_section = section.next
      path = for_edit ? edit_sectionable_path(next_section) : sectionable_slug_path(next_section)
      link_to path, data: hotkey_data_attributes("right", enabled: hotkey), class: "btn txt-medium min-width" do
        tag.span("Next: #{next_section.title }", class: "overflow-ellipsis") + image_tag("arrow-right.svg", aria: { hidden: true }, size: 24)
      end
    else
      link_to report_slug_path(section.report), data: hotkey_data_attributes("right", enabled: hotkey), class: "btn txt-medium" do
        tag.span("Table of contents: #{section.report.title }", class: "overflow-ellipsis") + image_tag("arrow-reverse.svg", aria: { hidden: true }, size: 24)
      end
    end
  end

  private
    def hotkey_data_attributes(key, enabled: true)
      if enabled
        { controller: "hotkey", action: "keydown.#{key}@document->hotkey#click touch:swipe-#{key}@window->hotkey#click" }
      end
    end
end
