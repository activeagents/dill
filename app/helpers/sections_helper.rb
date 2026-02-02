module SectionsHelper
  def section_item_tag(section, **, &)
    tag.li class: "arrangement__item toc__section toc__section--#{section.sectionable_name}",
      id: dom_id(section),
      data: {
        id: section.id,
        arrangement_target: "item"
      }, **, &
  end

  def section_nav_tag(section, **, &)
    tag.nav data: {
      controller: "reading-tracker",
      reading_tracker_report_id_value: section.report_id,
      reading_tracker_section_id_value: section.id
    }, **, &
  end

  def sectionable_edit_form(sectionable, **, &)
    form_with model: sectionable, url: sectionable_path(sectionable.section), method: :put, format: :html,
    data: {
      controller: "autosave",
      action: "autosave#submit:prevent input@document->autosave#change house-md:change->autosave#change",
      autosave_clean_class: "clean",
      autosave_dirty_class: "dirty",
      autosave_saving_class: "saving"
    }, **, &
  end
end
