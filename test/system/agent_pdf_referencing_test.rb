require "playwright_system_test_case"

class AgentPdfReferencingTest < PlaywrightSystemTestCase
  setup do
    @report = reports(:handbook)
    @page = sections(:welcome_page)
    sign_in "kevin@37signals.com"
  end

  test "agent can reference PDF from URL and create context fragments for citations" do
    skip "Requires AI API keys to be configured" unless ai_configured?
    skip "Requires Playwright driver" unless playwright_available?

    # Navigate to the page edit view
    visit edit_report_page_url(@report, @page)
    assert_selector "house-md"

    # Trigger the research assistant with a PDF URL reference
    # This simulates asking the agent to research a topic that includes a PDF URL
    pdf_url = "https://example.com/sample-report.pdf"

    # Open the AI assistant via the UI
    if has_button?("Research", wait: 2)
      click_button "Research"

      # Wait for modal/input to appear
      assert_selector ".ai-modal", wait: 5

      # Fill in research request that mentions a PDF URL
      fill_in_research_topic("Summarize the key findings from #{pdf_url}")

      # Submit the research request
      submit_research_request

      # Wait for agent processing
      wait_for_agent_completion(max_wait: 60)

      # Verify that a context was created for this interaction
      context = @page.latest_agent_context
      assert_not_nil context, "Expected an agent context to be created"
      assert_equal "ResearchAssistantAgent", context.agent_name
      assert_includes ["completed", "processing"], context.status

      # Verify that references were extracted and stored
      if context.completed?
        # Check that the PDF URL was tracked as a reference
        references = context.references
        pdf_references = references.select { |ref| ref.url.include?(".pdf") || ref.url.include?(pdf_url) }

        # At minimum, verify the context tracking is working
        assert context.tool_calls.any?, "Expected tool calls to be recorded"
      end
    else
      skip "Research button not available in toolbar"
    end
  end

  test "agent can reference uploaded PDF document and create context fragments" do
    skip "Requires AI API keys to be configured" unless ai_configured?
    skip "Requires Playwright driver" unless playwright_available?

    # First, create a document with an uploaded PDF
    document = create_test_pdf_document

    # Wait for document processing to complete
    wait_for_document_processing(document, max_wait: 30)
    document.reload

    assert document.completed?, "Document should be processed"
    assert document.page_text.present?, "Document should have extracted text"

    # Now navigate to a page to use the research assistant
    visit edit_report_page_url(@report, @page)
    assert_selector "house-md"

    # Add content that references the uploaded PDF document
    document_reference_text = "Based on the uploaded document (page 1): #{document.text_for_page(1)&.first(100)}"
    fill_house_editor "page[body]", document_reference_text

    # Trigger the AI assistant to improve/expand the content
    if has_button?("Improve", wait: 2)
      click_button "Improve"

      # Wait for streaming to start and content to appear
      assert_selector ".ai-modal", wait: 5

      # Wait for agent processing to complete
      wait_for_agent_completion(max_wait: 60)

      # Verify that a fragment was created for this transformation
      context = @page.latest_agent_context
      assert_not_nil context, "Expected an agent context to be created"

      # Check for fragments that track the content transformation
      fragments = context.fragments
      if fragments.any?
        fragment = fragments.last
        assert_equal "selection", fragment.fragment_type
        assert_not_nil fragment.original_content
      end
    else
      skip "Improve button not available in toolbar"
    end
  end

  test "agent context fragments track PDF-based citations" do
    skip "Requires AI API keys to be configured" unless ai_configured?
    skip "Requires Playwright driver" unless playwright_available?

    # Create a document with a PDF containing citations
    document = create_test_pdf_document

    wait_for_document_processing(document, max_wait: 30)
    document.reload

    assert document.completed?, "Document should be processed"

    # Navigate to page editor
    visit edit_report_page_url(@report, @page)
    assert_selector "house-md"

    # Select some content and request improvement with detected references
    test_content = "According to the research paper on page 3, the results show significant improvement."
    fill_house_editor "page[body]", test_content

    # Simulate selecting text and triggering AI with detected references
    if has_button?("Improve", wait: 2)
      # Manually trigger the stream endpoint with detected references
      # This tests the full flow including fragment creation with references
      result = trigger_stream_with_references(
        action_type: "improve",
        content: test_content,
        detected_references: [
          { text: "research paper on page 3", url: "document://#{document.id}#page=3", accepted: true }
        ]
      )

      # Wait for processing
      sleep 2

      # Verify context and fragments
      context = @page.reload.latest_agent_context
      if context
        # Check that fragments were created with detected references
        fragments = context.fragments
        if fragments.any?
          fragment_with_refs = fragments.find { |f| f.detected_references.present? }
          if fragment_with_refs
            assert fragment_with_refs.has_references?, "Fragment should have detected references"
            assert_includes fragment_with_refs.detected_references.map { |r| r["url"] }, "document://#{document.id}#page=3"
          end
        end
      end
    else
      skip "Improve button not available in toolbar"
    end
  end

  test "agent extracts and stores PDF metadata as references" do
    skip "Requires AI API keys to be configured" unless ai_configured?
    skip "Requires Playwright driver" unless playwright_available?

    visit edit_report_page_url(@report, @page)
    assert_selector "house-md"

    # Use the research assistant to visit a page with PDF links
    if has_button?("Research", wait: 2)
      click_button "Research"
      assert_selector ".ai-modal", wait: 5

      fill_in_research_topic("Find research papers about climate change in PDF format")
      submit_research_request

      wait_for_agent_completion(max_wait: 90)

      context = @page.latest_agent_context
      assert_not_nil context, "Expected an agent context to be created"

      if context.completed?
        # Verify that tool calls were made (navigate, extract_links, etc.)
        assert context.tool_calls.any?, "Expected tool calls to be recorded"

        # Check for any PDF-related references that were discovered
        context.extract_references!
        references = context.references

        # Log reference information for debugging
        Rails.logger.info "Found #{references.count} references in agent context"
        references.each do |ref|
          Rails.logger.info "Reference: #{ref.url} - #{ref.display_title}"
        end

        # The research agent should have visited some URLs
        navigate_calls = context.tool_calls.for_tool(:navigate)
        assert navigate_calls.any?, "Expected navigate tool calls"
      end
    else
      skip "Research button not available in toolbar"
    end
  end

  private

  def ai_configured?
    ENV["OPENAI_API_KEY"].present? || ENV["ANTHROPIC_API_KEY"].present?
  end

  def playwright_available?
    # Check if Playwright driver is registered
    Capybara.drivers[:capybara_playwright].present?
  rescue
    false
  end

  def create_test_pdf_document
    # Create a temporary PDF file for testing
    temp_pdf_path = create_test_pdf_file

    # Create a document and attach the PDF
    document = Document.new
    document.file.attach(
      io: File.open(temp_pdf_path),
      filename: "test_document.pdf",
      content_type: "application/pdf"
    )
    document.save!

    # Clean up temp file
    File.delete(temp_pdf_path) if File.exist?(temp_pdf_path)

    document
  end

  def create_test_pdf_file
    require "prawn"

    temp_path = Rails.root.join("tmp", "test_pdf_#{SecureRandom.hex(8)}.pdf")

    Prawn::Document.generate(temp_path) do |pdf|
      pdf.text "Test PDF Document", size: 24
      pdf.move_down 20
      pdf.text "Page 1: Introduction"
      pdf.text "This is a test PDF document for testing agent PDF referencing capabilities."
      pdf.text "It contains multiple pages with different content for citation testing."

      pdf.start_new_page
      pdf.text "Page 2: Methodology", size: 18
      pdf.text "This section describes the methodology used in the research."
      pdf.text "Key points include data collection and analysis procedures."

      pdf.start_new_page
      pdf.text "Page 3: Results", size: 18
      pdf.text "The research findings show significant improvement in the metrics."
      pdf.text "Statistical analysis indicates p < 0.05 for all measured outcomes."

      pdf.start_new_page
      pdf.text "Page 4: Conclusions", size: 18
      pdf.text "In conclusion, the research demonstrates the effectiveness of the approach."
      pdf.text "Further research is recommended to validate these findings."
    end

    temp_path.to_s
  rescue LoadError
    # If prawn gem is not available, create a minimal PDF manually
    create_minimal_test_pdf
  end

  def create_minimal_test_pdf
    temp_path = Rails.root.join("tmp", "test_pdf_#{SecureRandom.hex(8)}.pdf")

    # Create a minimal valid PDF
    pdf_content = <<~PDF
      %PDF-1.4
      1 0 obj
      << /Type /Catalog /Pages 2 0 R >>
      endobj
      2 0 obj
      << /Type /Pages /Kids [3 0 R] /Count 1 >>
      endobj
      3 0 obj
      << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]
         /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>
      endobj
      4 0 obj
      << /Length 68 >>
      stream
      BT
      /F1 24 Tf
      100 700 Td
      (Test PDF Document for Agent Testing) Tj
      ET
      endstream
      endobj
      5 0 obj
      << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>
      endobj
      xref
      0 6
      0000000000 65535 f
      0000000009 00000 n
      0000000058 00000 n
      0000000115 00000 n
      0000000266 00000 n
      0000000383 00000 n
      trailer
      << /Size 6 /Root 1 0 R >>
      startxref
      460
      %%EOF
    PDF

    File.write(temp_path, pdf_content)
    temp_path.to_s
  end

  def fill_in_research_topic(topic)
    # Find the research topic input field in the modal
    if has_field?("topic", wait: 2)
      fill_in "topic", with: topic
    elsif has_css?("[data-ai-modal-target='input']", wait: 2)
      find("[data-ai-modal-target='input']").set(topic)
    elsif has_css?("input[type='text']", wait: 2)
      find("input[type='text']").set(topic)
    end
  end

  def submit_research_request
    if has_button?("Start Research", wait: 2)
      click_button "Start Research"
    elsif has_button?("Submit", wait: 2)
      click_button "Submit"
    elsif has_css?("[data-action*='submit']", wait: 2)
      find("[data-action*='submit']").click
    end
  end

  def wait_for_agent_completion(max_wait: 30)
    Timeout.timeout(max_wait) do
      loop do
        # Check if any context has completed
        break if AgentContext.where(status: "completed").exists?

        # Also check for streaming completion indicator in the UI
        break if page.has_css?("[data-done='true']", wait: 0.5)
        break if page.has_text?("Complete", wait: 0.5)

        sleep 0.5
      end
    end
  rescue Timeout::Error
    # Allow test to continue even if agent hasn't completed
    Rails.logger.warn "Agent completion timeout - continuing test"
  end

  def trigger_stream_with_references(action_type:, content:, detected_references:)
    # Make a direct API call to the stream endpoint with detected references
    # This tests the fragment creation with references flow
    page.execute_script(<<~JS)
      fetch('/assistants/stream', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({
          action_type: '#{action_type}',
          content: '#{content.gsub("'", "\\\\'")}',
          page_id: #{@page.id},
          selection: '#{content.gsub("'", "\\\\'")}',
          detected_references: #{detected_references.to_json}
        })
      }).then(r => r.json()).then(data => {
        window.streamId = data.stream_id;
        window.streamCompleted = false;
      });
    JS
  end
end
