class HtmlScrubber < Rails::Html::PermitScrubber
  EXTRA_TAGS = %w[
    audio details summary iframe options table tbody td th thead tr video source mark
    del ins
  ].freeze

  EXTRA_ATTRIBUTES = %w[
    data-origin data-source-id data-suggestion-id data-reason
  ].freeze

  def initialize
    super
    self.tags = Rails::Html::WhiteListSanitizer.allowed_tags + EXTRA_TAGS
    self.attributes = Rails::Html::WhiteListSanitizer.allowed_attributes + EXTRA_ATTRIBUTES
  end
end
