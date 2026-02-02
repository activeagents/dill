class Reports::BookmarksController < ApplicationController
  allow_unauthenticated_access

  include ReportScoped

  def show
    @section = @report.sections.active.find_by(id: last_read_section_id) if last_read_section_id.present?
  end

  private
    def last_read_section_id
      cookies["reading_progress_#{@report.id}"]
    end
end
