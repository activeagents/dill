class Reports::Sections::MovesController < ApplicationController
  include ReportScoped

  before_action :ensure_editable

  def create
    section, *followed_by = sections
    section.move_to_position(position, followed_by: followed_by)
  end

  private
    def position
      params[:position].to_i
    end

    def sections
      @report.sections.find(Array(params[:id]))
    end
end
