class PicturesController < SectionablesController
  private
    def new_sectionable
      Picture.new sectionable_params
    end

    def sectionable_params
      params.fetch(:picture, {}).permit(:image, :caption)
    end
end
