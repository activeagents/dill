class DocumentProcessingJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(document, extract_images: true)
    return unless document.file.attached?

    document.processing!

    document.file.open do |tempfile|
      process_document(document, tempfile.path, extract_images: extract_images)
    end

    document.completed!
  rescue DocumentTextExtractor::UnsupportedFormatError => e
    handle_error(document, e, "Unsupported format")
  rescue PdfTextExtractor::ExtractionError => e
    handle_error(document, e, "PDF extraction failed")
  rescue PdfImageExtractor::ExtractionError => e
    handle_error(document, e, "PDF image extraction failed")
  rescue StandardError => e
    handle_error(document, e, "Processing failed")
    raise
  end

  private

  def process_document(document, file_path, extract_images: true)
    document_type = document.document_type || detect_type(document)

    case document_type
    when "pdf"
      process_pdf(document, file_path, extract_images: extract_images)
    when "pptx", "ppt"
      process_pptx(document, file_path)
    when "docx"
      process_docx(document, file_path)
    else
      raise DocumentTextExtractor::UnsupportedFormatError, "Unknown type: #{document_type}"
    end
  end

  def process_pdf(document, file_path, extract_images: true)
    # Extract text from all pages
    text_extractor = PdfTextExtractor.new(file_path)
    text_result = text_extractor.extract

    document.update!(
      page_count: text_result[:page_count],
      page_text: text_result[:pages],
      document_type: "pdf"
    )

    Rails.logger.info "[DocumentProcessingJob] Extracted #{text_result[:page_count]} pages of text from PDF #{document.id}"

    # Extract page images for VLM analysis
    if extract_images
      extract_and_store_page_images(document, file_path)
    end
  end

  def extract_and_store_page_images(document, file_path)
    image_extractor = PdfImageExtractor.new(file_path)
    image_paths = image_extractor.extract_all

    page_images = {}

    image_paths.each_with_index do |image_path, index|
      page_number = index + 1

      # Create Active Storage blob from the image
      blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(image_path, "rb"),
        filename: "#{document.id}_page_#{page_number}.png",
        content_type: "image/png",
        metadata: {
          document_id: document.id,
          page_number: page_number
        }
      )

      page_images[page_number.to_s] = blob.signed_id

      Rails.logger.debug "[DocumentProcessingJob] Stored page #{page_number} image as blob #{blob.id}"
    end

    document.update!(page_images: page_images)

    Rails.logger.info "[DocumentProcessingJob] Stored #{page_images.size} page images for document #{document.id}"
  ensure
    # Clean up temp directory
    if image_paths&.any?
      temp_dir = File.dirname(image_paths.first)
      FileUtils.rm_rf(temp_dir) if temp_dir.start_with?(Dir.tmpdir)
    end
  end

  def process_pptx(document, file_path)
    # Placeholder for PPTX processing
    # Would use ruby-pptx or libreoffice conversion
    Rails.logger.warn "[DocumentProcessingJob] PPTX extraction not yet implemented for document #{document.id}"

    document.update!(
      page_text: { "1" => "PPTX text extraction requires additional setup. See docs/features/pdf-ppt-support-and-context-retrieval.md" },
      page_count: 1,
      document_type: document.document_type || "pptx"
    )
  end

  def process_docx(document, file_path)
    # Placeholder for DOCX processing
    # Would use docx gem or libreoffice conversion
    Rails.logger.warn "[DocumentProcessingJob] DOCX extraction not yet implemented for document #{document.id}"

    document.update!(
      page_text: { "1" => "DOCX text extraction requires additional setup. See docs/features/pdf-ppt-support-and-context-retrieval.md" },
      page_count: 1,
      document_type: "docx"
    )
  end

  def detect_type(document)
    extension = File.extname(document.file.filename.to_s).downcase.delete(".")
    document.update!(document_type: extension) if extension.present?
    extension
  end

  def handle_error(document, error, message)
    Rails.logger.error "[DocumentProcessingJob] #{message} for document #{document.id}: #{error.message}"

    document.update!(
      processing_status: :failed,
      processing_error: "#{message}: #{error.message}"
    )
  end
end
