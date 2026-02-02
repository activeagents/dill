module Reports::EditingHelper
  def editing_mode_toggle_switch(section, checked:)
    target_url = checked ? sectionable_slug_path(section) : edit_sectionable_path(section)
    render "reports/edit_mode", target_url: target_url, checked: checked
  end
end
