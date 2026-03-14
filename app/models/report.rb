class Report < ApplicationRecord
  include Accessable, Sluggable, SolidAgent::Contextable

  has_many :sections, dependent: :destroy
  has_many :sources, dependent: :destroy
  has_many :information_requests, dependent: :destroy
  has_one_attached :cover, dependent: :purge_later

  scope :ordered, -> { order(:title) }
  scope :published, -> { where(published: true) }

  enum :theme, %w[ black blue green magenta orange violet white ].index_by(&:itself), suffix: true, default: :blue

  def press(sectionable, section_params)
    sections.create! section_params.merge(sectionable: sectionable)
  end

  # Get all documents attached to this report via sections
  def documents
    Document.joins(:section).where(sections: { report_id: id })
  end

  # Convert this report's structure to a template schema
  def to_template_schema
    sections.order(:position_score).map do |section|
      {
        "title" => section.title,
        "type" => section.sectionable_type,
        "instructions" => "",
        "placeholder" => extract_section_placeholder(section.sectionable),
        "required" => true
      }
    end
  end

  # Outstanding information requests for this report
  def outstanding_requests
    information_requests.outstanding.by_priority
  end

  private

  def extract_section_placeholder(sectionable)
    case sectionable
    when Page
      sectionable.body.presence || ""
    when TextBlock
      sectionable.plain_text.presence || ""
    when Finding
      sectionable.description.presence || ""
    else
      ""
    end
  end
end
