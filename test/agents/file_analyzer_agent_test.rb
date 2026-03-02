require "test_helper"
require "ostruct"

class FileAnalyzerAgentTest < ActiveSupport::TestCase
  setup do
    @temp_dir = Rails.root.join('tmp', "test_files_#{Process.pid}_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(@temp_dir)
  end

  teardown do
    FileUtils.rm_rf(@temp_dir)
  end

  test "agent is defined and inherits from ApplicationAgent" do
    assert defined?(FileAnalyzerAgent)
    assert FileAnalyzerAgent < ApplicationAgent
  end

  test "has analyze_pdf action" do
    assert FileAnalyzerAgent.instance_methods.include?(:analyze_pdf)
  end

  test "has analyze_image action" do
    assert FileAnalyzerAgent.instance_methods.include?(:analyze_image)
  end

  test "has extract_text action" do
    assert FileAnalyzerAgent.instance_methods.include?(:extract_text)
  end

  test "has summarize_document action" do
    assert FileAnalyzerAgent.instance_methods.include?(:summarize_document)
  end

  test "encode_image_for_prompt detects PNG content type" do
    # Create a minimal PNG file
    temp_file = @temp_dir.join('test.png')
    File.binwrite(temp_file, "\x89PNG\r\n\x1a\n") # PNG header bytes

    agent = FileAnalyzerAgent.new
    agent.instance_variable_set(:@file_path, temp_file.to_s)
    agent.send(:encode_image_for_prompt)

    image_data = agent.instance_variable_get(:@image_data)
    assert_not_nil image_data
    assert image_data.start_with?('data:image/png;base64,')
  end

  test "encode_image_for_prompt detects JPEG content type" do
    temp_file = @temp_dir.join('test.jpg')
    File.binwrite(temp_file, "\xFF\xD8\xFF") # JPEG header bytes

    agent = FileAnalyzerAgent.new
    agent.instance_variable_set(:@file_path, temp_file.to_s)
    agent.send(:encode_image_for_prompt)

    image_data = agent.instance_variable_get(:@image_data)
    assert_not_nil image_data
    assert image_data.start_with?('data:image/jpeg;base64,')
  end

  test "encode_image_for_prompt detects GIF content type" do
    temp_file = @temp_dir.join('test.gif')
    File.binwrite(temp_file, "GIF89a")

    agent = FileAnalyzerAgent.new
    agent.instance_variable_set(:@file_path, temp_file.to_s)
    agent.send(:encode_image_for_prompt)

    image_data = agent.instance_variable_get(:@image_data)
    assert_not_nil image_data
    assert image_data.start_with?('data:image/gif;base64,')
  end

  test "encode_image_for_prompt detects WebP content type" do
    temp_file = @temp_dir.join('test.webp')
    File.binwrite(temp_file, "RIFF\x00\x00\x00\x00WEBP")

    agent = FileAnalyzerAgent.new
    agent.instance_variable_set(:@file_path, temp_file.to_s)
    agent.send(:encode_image_for_prompt)

    image_data = agent.instance_variable_get(:@image_data)
    assert_not_nil image_data
    assert image_data.start_with?('data:image/webp;base64,')
  end

  test "encode_image_for_prompt does nothing when file does not exist" do
    agent = FileAnalyzerAgent.new
    agent.instance_variable_set(:@file_path, '/nonexistent/path/image.jpg')
    agent.send(:encode_image_for_prompt)

    image_data = agent.instance_variable_get(:@image_data)
    assert_nil image_data
  end

  test "encode_image_for_prompt does nothing when file_path is nil" do
    agent = FileAnalyzerAgent.new
    agent.instance_variable_set(:@file_path, nil)
    agent.send(:encode_image_for_prompt)

    image_data = agent.instance_variable_get(:@image_data)
    assert_nil image_data
  end

  test "extract_file_content reads file content" do
    temp_file = @temp_dir.join('test.txt')
    File.write(temp_file, "Hello, World!")

    agent = FileAnalyzerAgent.new
    content = agent.send(:extract_file_content, temp_file.to_s)

    assert_equal "Hello, World!", content
  end

  test "extract_file_content returns error message when file cannot be read" do
    agent = FileAnalyzerAgent.new
    content = agent.send(:extract_file_content, '/nonexistent/file.txt')

    assert_equal "Unable to read file content", content
  end

  test "encode_image_to_base64 returns nil for non-existent file" do
    agent = FileAnalyzerAgent.new
    result = agent.send(:encode_image_to_base64, '/nonexistent/image.jpg')

    assert_nil result
  end

  test "broadcast_chunk does nothing without stream_id" do
    agent = FileAnalyzerAgent.new
    # Should not raise an error
    chunk = OpenStruct.new(delta: "test content")
    assert_nothing_raised { agent.send(:broadcast_chunk, chunk) }
  end

  test "broadcast_chunk does nothing when chunk has no delta" do
    agent = FileAnalyzerAgent.new
    chunk = OpenStruct.new(delta: nil)
    assert_nothing_raised { agent.send(:broadcast_chunk, chunk) }
  end

  test "broadcast_complete does nothing without stream_id" do
    agent = FileAnalyzerAgent.new
    chunk = OpenStruct.new
    assert_nothing_raised { agent.send(:broadcast_complete, chunk) }
  end

  test "can be instantiated with params" do
    agent = FileAnalyzerAgent.with(
      file_path: '/path/to/file.jpg',
      description_detail: 'detailed',
      stream_id: 'test_123'
    )

    assert_not_nil agent
  end

  # ============================================
  # Temp file cleanup tests
  # ============================================

  test "cleanup_temp_file deletes upload_* files in tmp directory" do
    temp_file = Rails.root.join("tmp", "upload_abc123_test.png")
    File.write(temp_file, "fake image data")
    assert File.exist?(temp_file)

    agent = FileAnalyzerAgent.new
    agent.send(:cleanup_temp_file, temp_file.to_s)

    assert_not File.exist?(temp_file), "upload_* temp file should have been deleted"
  end

  test "cleanup_temp_file does not delete non-upload files in tmp directory" do
    temp_file = Rails.root.join("tmp", "important_data.txt")
    File.write(temp_file, "important data")
    assert File.exist?(temp_file)

    agent = FileAnalyzerAgent.new
    agent.send(:cleanup_temp_file, temp_file.to_s)

    assert File.exist?(temp_file), "Non-upload file should not have been deleted"
  ensure
    File.delete(temp_file) if File.exist?(temp_file)
  end

  test "cleanup_temp_file does not delete upload_* files outside tmp directory" do
    outside_file = @temp_dir.join("upload_abc123_test.png")
    File.write(outside_file, "fake image data")
    assert File.exist?(outside_file)

    agent = FileAnalyzerAgent.new
    agent.send(:cleanup_temp_file, outside_file.to_s)

    assert File.exist?(outside_file), "File outside tmp/ should not have been deleted"
  end

  test "cleanup_temp_file handles nil file_path gracefully" do
    agent = FileAnalyzerAgent.new
    assert_nothing_raised { agent.send(:cleanup_temp_file, nil) }
  end

  test "cleanup_temp_file handles non-existent file gracefully" do
    agent = FileAnalyzerAgent.new
    assert_nothing_raised { agent.send(:cleanup_temp_file, Rails.root.join("tmp", "upload_nonexistent.png").to_s) }
  end

  # ============================================
  # Image encoding dispatch tests
  # ============================================

  test "encode_image uses file path when file exists" do
    temp_file = @temp_dir.join("test_dispatch.png")
    File.binwrite(temp_file, "\x89PNG\r\n\x1a\n")

    agent = FileAnalyzerAgent.new
    agent.instance_variable_set(:@file_path, temp_file.to_s)
    agent.send(:encode_image)

    image_data = agent.instance_variable_get(:@image_data)
    assert_not_nil image_data
    assert image_data.start_with?("data:image/png;base64,"), "Should encode from file path"
  end

  test "encode_image falls back to attachment when file_path is nil" do
    agent = FileAnalyzerAgent.new
    agent.instance_variable_set(:@file_path, nil)

    # With no file path and no attachment slug, encode_image_from_attachment
    # will log a warning and return nil — this is expected behavior
    agent.stub(:params, { attachment_slug: nil }) do
      agent.send(:encode_image)
    end

    image_data = agent.instance_variable_get(:@image_data)
    assert_nil image_data, "Should be nil when no file path and no attachment"
  end

  test "encode_image falls back to attachment when file does not exist" do
    agent = FileAnalyzerAgent.new
    agent.instance_variable_set(:@file_path, "/nonexistent/path.jpg")

    agent.stub(:params, { attachment_slug: nil }) do
      agent.send(:encode_image)
    end

    image_data = agent.instance_variable_get(:@image_data)
    assert_nil image_data, "Should fall back to attachment path when file doesn't exist"
  end
end
