class DocumentsController < SectionablesController
  private

  def new_sectionable
    Document.new sectionable_params
  end

  def sectionable_params
    params.fetch(:document, {}).permit(:file)
  end
end
