module PageLeafScoped extend ActiveSupport::Concern
  included do
    before_action :set_section
  end

  private
    def set_section
      page = Page.find(params[:page_id])
      @section = page.section
    end
end
