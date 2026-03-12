namespace :tech_diligence do
  desc "Process a PDF document and extract page images"
  task :process_pdf, [:file_path] => :environment do |t, args|
    file_path = args[:file_path]

    unless file_path && File.exist?(file_path)
      puts "Usage: rake tech_diligence:process_pdf[/path/to/file.pdf]"
      puts "Error: File not found: #{file_path}"
      exit 1
    end

    puts "Creating document from: #{file_path}"

    # Create a document and attach the file
    document = Document.new
    document.file.attach(
      io: File.open(file_path),
      filename: File.basename(file_path),
      content_type: "application/pdf"
    )
    document.save!

    puts "Document created with ID: #{document.id}"
    puts "Processing document (text + images)..."

    # Process synchronously for testing
    DocumentProcessingJob.perform_now(document)

    document.reload
    puts "\nProcessing complete!"
    puts "  Page count: #{document.page_count}"
    puts "  Pages with text: #{document.page_text.keys.count}"
    puts "  Pages with images: #{document.page_images.keys.count}"
    puts "  Status: #{document.processing_status}"

    if document.page_images.any?
      puts "\nPage images stored as Active Storage blobs:"
      document.page_images.each do |page_num, signed_id|
        blob = ActiveStorage::Blob.find_signed(signed_id)
        puts "  Page #{page_num}: #{blob.filename} (#{blob.byte_size} bytes)"
      end
    end

    puts "\nDocument ID for API calls: #{document.id}"
  end

  desc "Ask questions about a document"
  task :ask, [:document_id, :question] => :environment do |t, args|
    document = Document.find(args[:document_id])
    question = args[:question] || "What are the main specifications?"

    puts "Document: #{document.file.filename}"
    puts "Question: #{question}"
    puts "Processing with vision: #{document.has_page_images?}"
    puts "\n" + "=" * 60 + "\n"

    # Run synchronously for CLI output
    agent = TechDiligenceAgent.with(
      document: document,
      questions: [question],
      use_vision: true
    )

    response = agent.answer_questions.generate

    puts response.message.content
    puts "\n" + "=" * 60

    # Show any fragments created
    if agent.context&.fragments&.any?
      puts "\nProvenance fragments created:"
      agent.context.fragments.each do |fragment|
        puts "  - Page #{fragment.source_page_number}: #{fragment.generated_content&.truncate(100)}"
      end
    end
  end

  desc "Extract specs from a document"
  task :extract_specs, [:document_id] => :environment do |t, args|
    document = Document.find(args[:document_id])

    puts "Document: #{document.file.filename}"
    puts "Extracting specifications..."
    puts "\n" + "=" * 60 + "\n"

    agent = TechDiligenceAgent.with(
      document: document,
      spec_categories: %w[cpu memory storage connectivity power form_factor]
    )

    response = agent.extract_specs.generate

    puts response.message.content
  end

  desc "Test the full pipeline with example questions"
  task :test_motherboard, [:document_id] => :environment do |t, args|
    document = Document.find(args[:document_id])

    questions = [
      "What is the CPU socket type?",
      "What is the maximum recommended RAM speed?",
      "Does it have an optical audio port?",
      "What PCIe slots are available?",
      "What is the chipset model?"
    ]

    puts "Testing Tech Diligence Agent with #{document.file.filename}"
    puts "=" * 60
    puts "Questions:"
    questions.each_with_index { |q, i| puts "  #{i + 1}. #{q}" }
    puts "=" * 60 + "\n"

    agent = TechDiligenceAgent.with(
      document: document,
      questions: questions,
      use_vision: true
    )

    response = agent.answer_questions.generate

    puts response.message.content

    # Summary
    puts "\n" + "=" * 60
    puts "Analysis complete!"
    puts "  Document: #{document.file.filename}"
    puts "  Pages analyzed: #{document.page_count}"
    puts "  Vision used: #{document.has_page_images?}"

    if agent.context&.fragments&.any?
      puts "  Citations tracked: #{agent.context.fragments.count}"
    end
  end
end
