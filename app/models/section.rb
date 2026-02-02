class Section < ApplicationRecord
  include Editable, Positionable, Searchable, Contextable

  belongs_to :report, touch: true
  delegated_type :sectionable, types: Sectionable::TYPES, dependent: :destroy
  positioned_within :report, association: :sections, filter: :active

  delegate :searchable_content, to: :sectionable

  enum :status, %w[ active trashed ].index_by(&:itself), default: :active

  scope :with_sectionables, -> { includes(:sectionable) }

  def slug
    title.parameterize.presence || "-"
  end
end
