class TextBlocksController < SectionablesController
  private
    def new_sectionable
      TextBlock.new sectionable_params
    end

    def sectionable_params
      params.fetch(:text_block, {}).permit(:body, :theme)
        .with_defaults(body: default_body)
    end

    def default_body
      params.fetch(:section, {})[:title]
    end
end
