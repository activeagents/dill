class FindingsController < SectionablesController
  private

  def default_section_params
    { title: "New Finding" }
  end

  def new_sectionable
    Finding.new sectionable_params
  end

  def sectionable_params
    params.fetch(:finding, {}).permit(:severity, :status, :category, :description, :recommendation, :evidence)
  end
end
