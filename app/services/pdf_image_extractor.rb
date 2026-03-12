require "open3"
require "fileutils"

class PdfImageExtractor
  class ExtractionError < StandardError; end

  attr_reader :file_path

  DPI = 150 # Good balance of quality vs file size for VLM analysis
  FORMAT = "png"

  def initialize(file_path)
    @file_path = file_path
    validate_file!
  end

  # Extract all pages as images, returns array of image paths
  # Caller is responsible for cleanup of temp files
  def extract_all
    output_dir = create_temp_dir
    output_prefix = File.join(output_dir, "page")

    run_pdftoppm(output_prefix)

    # pdftoppm outputs: page-1.png, page-2.png, etc.
    Dir.glob(File.join(output_dir, "page-*.#{FORMAT}")).sort_by do |path|
      # Extract page number for proper sorting (page-1, page-2, ..., page-10)
      path.match(/page-(\d+)\.#{FORMAT}$/)[1].to_i
    end
  end

  # Extract a single page as an image, returns image path
  def extract_page(page_number)
    output_dir = create_temp_dir
    output_prefix = File.join(output_dir, "page")

    run_pdftoppm(output_prefix, first_page: page_number, last_page: page_number)

    # Find the generated file
    Dir.glob(File.join(output_dir, "page-*.#{FORMAT}")).first
  end

  # Extract pages and return as base64-encoded data URIs for direct VLM use
  def extract_page_as_base64(page_number)
    image_path = extract_page(page_number)
    return nil unless image_path && File.exist?(image_path)

    base64_data = Base64.strict_encode64(File.binread(image_path))
    "data:image/#{FORMAT};base64,#{base64_data}"
  ensure
    cleanup_temp_file(image_path) if image_path
  end

  def page_count
    @page_count ||= count_pages
  end

  private

  def validate_file!
    raise ExtractionError, "File not found: #{file_path}" unless File.exist?(file_path)
    raise ExtractionError, "Not a PDF file" unless File.extname(file_path).downcase == ".pdf"
  end

  def create_temp_dir
    dir = Dir.mktmpdir("pdf_images_")
    Rails.logger.info "[PdfImageExtractor] Created temp dir: #{dir}"
    dir
  end

  def run_pdftoppm(output_prefix, first_page: nil, last_page: nil)
    cmd = build_command(output_prefix, first_page, last_page)

    Rails.logger.info "[PdfImageExtractor] Running: #{cmd.join(' ')}"

    stdout, stderr, status = Open3.capture3(*cmd)

    unless status.success?
      Rails.logger.error "[PdfImageExtractor] pdftoppm failed: #{stderr}"
      raise ExtractionError, "PDF to image conversion failed: #{stderr}"
    end

    Rails.logger.info "[PdfImageExtractor] Conversion complete"
  end

  def build_command(output_prefix, first_page, last_page)
    cmd = ["pdftoppm", "-#{FORMAT}", "-r", DPI.to_s]
    cmd += ["-f", first_page.to_s] if first_page
    cmd += ["-l", last_page.to_s] if last_page
    cmd += [file_path, output_prefix]
    cmd
  end

  def count_pages
    # Use pdfinfo to get page count quickly
    stdout, stderr, status = Open3.capture3("pdfinfo", file_path)

    if status.success? && stdout =~ /Pages:\s+(\d+)/
      $1.to_i
    else
      # Fallback: use pdf-reader
      require "pdf-reader"
      PDF::Reader.new(file_path).page_count
    end
  rescue => e
    Rails.logger.warn "[PdfImageExtractor] Could not determine page count: #{e.message}"
    0
  end

  def cleanup_temp_file(path)
    return unless path && File.exist?(path)

    dir = File.dirname(path)
    FileUtils.rm_rf(dir) if dir.start_with?(Dir.tmpdir)
  end
end
