module SetReportSection
  extend ActiveSupport::Concern

  included do
    before_action :set_report
    before_action :set_section, :set_sectionable, only: %i[ show edit update destroy ]
  end

  private
    def set_report
      @report = Report.accessable_or_published.find(params[:report_id])
    end

    def set_section
      @section = @report.sections.active.find(params[:id])
    end

    def set_sectionable
      instance_variable_set "@#{instance_name}", @section.sectionable
    end

    def ensure_editable
      head :forbidden unless @report.editable?
    end

    def model_class
      controller_sectionable_name.constantize
    end

    def instance_name
      controller_sectionable_name.underscore
    end

    def controller_sectionable_name
      self.class.to_s.remove("Controller").demodulize.singularize
    end
end
