class PagesController < SectionablesController
  before_action :forget_reading_progress, except: :show

  private
    def forget_reading_progress
      cookies.delete "reading_progress_#{@report.id}"
    end

    def default_section_params
      { title: "Untitled" }
    end

    def new_sectionable
      Page.new sectionable_params
    end

    def sectionable_params
      params.fetch(:page, {}).permit(:body)
    end
end
