class Report < ApplicationRecord
  include Accessable, Sluggable, SolidAgent::Contextable

  has_many :sections, dependent: :destroy
  has_many :sources, dependent: :destroy
  has_one_attached :cover, dependent: :purge_later

  scope :ordered, -> { order(:title) }
  scope :published, -> { where(published: true) }

  enum :theme, %w[ black blue green magenta orange violet white ].index_by(&:itself), suffix: true, default: :blue

  def press(sectionable, section_params)
    sections.create! section_params.merge(sectionable: sectionable)
  end
end
