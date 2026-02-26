# ReferencesController provides endpoints for managing research references
# associated with pages and other sectionable content.
#
# References are automatically extracted from ResearchAssistantAgent tool calls
# and can be displayed, copied, and used for citations.
class ReferencesController < ApplicationController
  before_action :set_section

  # GET /reports/:report_id/sections/:section_id/references
  # Returns references for a specific section's sectionable (page, etc.)
  def index
    @references = @section.sectionable.research_references.with_metadata

    respond_to do |format|
      format.html { render partial: "references/list", locals: { references: @references, section: @section } }
      format.json { render json: { references: @references.map(&:as_card) } }
    end
  end

  private

  def set_section
    @report = Report.find(params[:report_id])
    @section = @report.sections.find(params[:section_id])
  end
end
