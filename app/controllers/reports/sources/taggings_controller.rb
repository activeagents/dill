class Reports::Sources::TaggingsController < ApplicationController
  include ReportScoped

  before_action :ensure_editable
  before_action :set_source

  def create
    sectionable = find_sectionable(params[:taggable_type], params[:taggable_id])

    sectionable.tag_source(@source,
      context: params[:context],
      excerpt: params[:excerpt])

    redirect_back fallback_location: report_source_path(@report, @source),
      notice: "Section mapped to outline"
  end

  def destroy
    source_tag = @source.source_tags.find(params[:id])
    source_tag.destroy

    redirect_back fallback_location: report_source_path(@report, @source),
      notice: "Section unmapped from outline"
  end

  private

  def set_source
    @source = @report.sources.find(params[:source_id])
  end

  def find_sectionable(type, id)
    raise ActionController::BadRequest, "Invalid taggable type" unless type.in?(Sectionable::TYPES)
    type.constantize.find(id)
  end
end
