class SectionablesController < ApplicationController
  allow_unauthenticated_access only: :show

  include SetReportSection

  before_action :ensure_editable, except: :show
  before_action :broadcast_being_edited_indicator, only: :update

  def new
    @sectionable = new_sectionable
  end

  def create
    @section = @report.press new_sectionable, section_params
    position_new_section @section
  end

  def show
  end

  def edit
  end

  def update
    @section.edit sectionable_params: sectionable_params, section_params: section_params

    respond_to do |format|
      format.turbo_stream { render }
      format.html { head :no_content }
    end
  end

  def destroy
    @section.trashed!

    respond_to do |format|
      format.turbo_stream { render }
      format.html { redirect_to report_slug_url(@report) }
    end
  end

  private
    def section_params
      default_section_params.merge params.fetch(:section, {}).permit(:title)
    end

    def default_section_params
      { title: new_sectionable.model_name.human }
    end

    def new_sectionable
      raise NotImplementedError.new "Implement in subclass"
    end

    def sectionable_params
      raise NotImplementedError.new "Implement in subclass"
    end

    def position_new_section(section)
      if position = params[:position]&.to_i
        section.move_to_position position
      end
    end

    def broadcast_being_edited_indicator
      Turbo::StreamsChannel.broadcast_render_later_to @section, :being_edited,
        partial: "sections/being_edited_by", locals: { section: @section, user: Current.user }
    end
end
