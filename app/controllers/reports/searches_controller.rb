class Reports::SearchesController < ApplicationController
  allow_unauthenticated_access

  include ReportScoped

  def create
    @sections = @report.sections.active.search(params[:search]).favoring_title.limit(50)
  end
end
