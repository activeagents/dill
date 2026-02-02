module Sectionable
  extend ActiveSupport::Concern

  TYPES = %w[ Page TextBlock Picture Document Finding ]

  included do
    include SolidAgent::Contextable

    has_one :section, as: :sectionable, inverse_of: :sectionable, touch: true
    has_one :report, through: :section

    delegate :title, to: :section
  end

  def searchable_content
    nil
  end

  class_methods do
    def sectionable_name
      @sectionable_name ||= ActiveModel::Name.new(self).singular.inquiry
    end
  end

  def sectionable_name
    self.class.sectionable_name
  end
end
