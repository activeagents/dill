class Document < ApplicationRecord
  include Sectionable

  SUPPORTED_TYPES = %w[pdf pptx ppt docx].freeze
  PROCESSING_STATUSES = %w[pending processing completed failed].freeze

  has_one_attached :file

  validates :document_type, inclusion: { in: SUPPORTED_TYPES }, allow_nil: true

  enum :processing_status, PROCESSING_STATUSES.index_by(&:itself), default: :pending

  after_create_commit :process_document_async, if: :file_attached?
  after_update_commit :reindex_section, if: :should_reindex?

  def searchable_content
    return nil if page_text.blank?

    page_text.values.join("\n")
  end

  def text_for_page(page_number)
    page_text[page_number.to_s]
  end

  def text_for_pages(range)
    range.map { |n| page_text[n.to_s] }.compact.join("\n\n---\n\n")
  end

  def image_for_page(page_number)
    page_images[page_number.to_s]
  end

  # Returns the Active Storage blob for a page image
  def image_blob_for_page(page_number)
    signed_id = image_for_page(page_number)
    return nil unless signed_id

    ActiveStorage::Blob.find_signed(signed_id)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  # Returns base64-encoded image data URI for VLM analysis
  def image_data_uri_for_page(page_number)
    blob = image_blob_for_page(page_number)
    return nil unless blob

    blob.open do |tempfile|
      base64_data = Base64.strict_encode64(tempfile.read)
      "data:#{blob.content_type};base64,#{base64_data}"
    end
  end

  # Check if page images have been extracted
  def has_page_images?
    page_images.present? && page_images.any?
  end

  def context_for_pages(range)
    range.map do |n|
      text = page_text[n.to_s]

      if text.blank? || text.length < 50
        { type: :image, blob_id: image_for_page(n), page: n }
      else
        { type: :text, content: text, page: n }
      end
    end
  end

  def pdf?
    document_type == "pdf"
  end

  def pptx?
    document_type.in?(%w[pptx ppt])
  end

  def docx?
    document_type == "docx"
  end

  def file_attached?
    file.attached?
  end

  def detect_document_type
    return unless file.attached?

    extension = File.extname(file.filename.to_s).downcase.delete(".")
    self.document_type = extension if extension.in?(SUPPORTED_TYPES)
  end

  private

  def process_document_async
    detect_document_type
    save! if document_type_changed?

    DocumentProcessingJob.perform_later(self)
  end

  def should_reindex?
    saved_change_to_page_text? || saved_change_to_processing_status?
  end

  def reindex_section
    return unless section&.persisted?

    section.reindex
    Rails.logger.info "[Document] Reindexed section #{section.id} for document #{id}"
  end
end
