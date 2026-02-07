class Source < ApplicationRecord
  SOURCE_TYPES = %w[pdf image text url outline].freeze
  PROCESSING_STATUSES = %w[pending processing completed failed].freeze

  belongs_to :report

  has_many :source_tags, dependent: :destroy
  has_one_attached :file

  validates :name, presence: true
  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :url, presence: true, if: -> { source_type == "url" }

  enum :processing_status, PROCESSING_STATUSES.index_by(&:itself), default: :pending

  scope :ordered, -> { order(created_at: :desc) }
  scope :processed, -> { where(processing_status: :completed) }
  scope :outlines, -> { where(source_type: "outline") }
  scope :non_outlines, -> { where.not(source_type: "outline") }

  after_create_commit :process_source_async

  def pdf?
    source_type == "pdf"
  end

  def image?
    source_type == "image"
  end

  def text?
    source_type == "text"
  end

  def url?
    source_type == "url"
  end

  def outline?
    source_type == "outline"
  end

  def file_attached?
    file.attached?
  end

  def context_for_ai
    return extracted_content if extracted_content.present?
    return raw_content if raw_content.present?

    nil
  end

  def outline_context_for_ai
    return nil unless outline?

    sections = structured_content&.dig("sections")
    return extracted_content unless sections.present? && sections.any?

    sections.map do |section|
      heading = section["heading"]
      content = section["content"]
      key_points = section["key_points"]&.map { |p| "  - #{p}" }&.join("\n")

      parts = []
      parts << "### #{heading}" if heading.present?
      parts << content if content.present?
      parts << "Key Points:\n#{key_points}" if key_points.present?
      parts.join("\n")
    end.join("\n\n---\n\n")
  end

  def display_name
    name.presence || file&.filename&.to_s || url&.truncate(50) || "Untitled Source"
  end

  private

  def process_source_async
    SourceProcessingJob.perform_later(self)
  end
end
