require "test_helper"

class PdfReferencingIntegrationTest < ActiveSupport::TestCase
  setup do
    @report = reports(:handbook)
    @page = sections(:welcome_page).sectionable
  end

  test "agent context can store PDF URL references" do
    context = AgentContext.create!(
      agent_name: "ResearchAssistantAgent",
      contextable: @page,
      action_name: "research",
      instructions: "Research topic with PDF sources"
    )

    # Create a reference to a PDF URL
    pdf_reference = context.references.create!(
      url: "https://example.com/research-paper.pdf",
      title: "Research Paper PDF",
      status: "complete"
    )

    assert pdf_reference.persisted?
    assert_equal "example.com", pdf_reference.domain
    assert_equal "[Research Paper PDF](https://example.com/research-paper.pdf)", pdf_reference.to_markdown_link
  end

  test "agent context tracks PDF tool calls" do
    context = AgentContext.create!(
      agent_name: "ResearchAssistantAgent",
      contextable: @page
    )

    # Simulate a navigate tool call to a PDF URL
    tool_call = context.record_tool_call_start(
      name: :navigate,
      arguments: { url: "https://example.com/document.pdf" }
    )

    context.record_tool_call_complete(tool_call, result: {
      success: true,
      current_url: "https://example.com/document.pdf",
      title: "Important PDF Document"
    })

    # Extract references from tool calls
    refs = context.extract_references!

    assert_equal 1, refs.length
    assert_equal "https://example.com/document.pdf", refs.first.url
    assert_equal "Important PDF Document", refs.first.title
  end

  test "agent fragment can store detected PDF references" do
    context = AgentContext.create!(
      agent_name: "WritingAssistantAgent",
      contextable: @page
    )

    # Create a fragment with detected PDF references
    fragment = context.fragments.create!(
      contextable: @page,
      original_content: "According to the PDF on page 3, results show improvement.",
      action_type: "improve",
      fragment_type: "selection",
      detected_references: [
        {
          "text" => "PDF on page 3",
          "url" => "document://123#page=3",
          "accepted" => true
        },
        {
          "text" => "external paper",
          "url" => "https://example.com/paper.pdf",
          "accepted" => true
        }
      ]
    )

    assert fragment.persisted?
    assert fragment.has_references?
    assert_equal 2, fragment.accepted_references.length
    assert_equal "document://123#page=3", fragment.accepted_references.first["url"]
  end

  test "document stores extracted PDF text for referencing" do
    # Create a minimal test PDF
    temp_path = create_test_pdf_content

    document = Document.new
    document.file.attach(
      io: File.open(temp_path),
      filename: "test.pdf",
      content_type: "application/pdf"
    )
    document.document_type = "pdf"
    document.page_text = { "1" => "Page 1 content for citation" }
    document.page_count = 1
    document.processing_status = "completed"
    document.save!

    # Clean up
    File.delete(temp_path) if File.exist?(temp_path)

    assert document.persisted?
    assert_equal "Page 1 content for citation", document.text_for_page(1)
    assert document.completed?
  end

  test "context retrieval includes PDF document references" do
    # Create a document with PDF content
    document = Document.create!(
      document_type: "pdf",
      page_text: {
        "1" => "Executive Summary: This report analyzes market trends.",
        "2" => "Methodology: Data collection and analysis procedures.",
        "3" => "Results: Key findings indicate positive growth."
      },
      page_count: 3,
      processing_status: "completed"
    )

    # Verify we can retrieve text for specific pages
    assert_equal "Executive Summary: This report analyzes market trends.", document.text_for_page(1)
    assert_includes document.text_for_pages(1..2), "Methodology"

    # Verify context_for_pages returns proper format
    context = document.context_for_pages(1..1)
    assert_equal 1, context.length
    assert_equal :text, context.first[:type]
    assert_equal 1, context.first[:page]
  end

  test "agent reference extracts PDF metadata from tool results" do
    context = AgentContext.create!(
      agent_name: "ResearchAssistantAgent"
    )

    # Simulate extract_links tool call that found PDF links
    tool_call = context.record_tool_call_start(
      name: :extract_links,
      arguments: { selector: "body", limit: 10 }
    )

    context.record_tool_call_complete(tool_call, result: {
      success: true,
      links: [
        { text: "Annual Report 2025", href: "https://company.com/annual-report-2025.pdf", title: nil },
        { text: "Research Paper", href: "https://journal.com/paper.pdf", title: "Peer-reviewed research" },
        { text: "Web Article", href: "https://news.com/article", title: nil }
      ],
      current_url: "https://company.com/resources"
    })

    # Extract references
    refs = context.extract_references!

    # Should have created references for all links including PDFs
    assert refs.any?

    # Find PDF-specific references
    pdf_refs = context.references.select { |r| r.url.end_with?(".pdf") }
    assert_equal 2, pdf_refs.length

    pdf_titles = pdf_refs.map(&:title)
    assert_includes pdf_titles, "Annual Report 2025"
    assert_includes pdf_titles, "Research Paper"
  end

  test "fragment version history preserves PDF citation changes" do
    context = AgentContext.create!(
      agent_name: "WritingAssistantAgent",
      contextable: @page
    )

    # Create original fragment
    original_fragment = context.fragments.create!(
      contextable: @page,
      original_content: "The results show improvement.",
      action_type: "improve",
      fragment_type: "selection",
      detected_references: []
    )

    # User adds a PDF citation and regenerates
    regenerated_fragment = original_fragment.regenerate_with(
      new_references: [
        { "text" => "page 5 of the study", "url" => "document://456#page=5", "accepted" => true }
      ]
    )

    assert_equal original_fragment.id, regenerated_fragment.parent_fragment_id
    assert regenerated_fragment.detected_references.any?

    # Version history should include both
    history = regenerated_fragment.version_history
    assert_equal 2, history.length
    assert_equal original_fragment.id, history.first.id
    assert_equal regenerated_fragment.id, history.last.id
  end

  private

  def create_test_pdf_content
    temp_path = Rails.root.join("tmp", "test_pdf_#{SecureRandom.hex(8)}.pdf")

    # Create a minimal valid PDF
    pdf_content = <<~PDF
      %PDF-1.4
      1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
      2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
      3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >> endobj
      xref
      0 4
      0000000000 65535 f
      0000000009 00000 n
      0000000058 00000 n
      0000000115 00000 n
      trailer << /Size 4 /Root 1 0 R >>
      startxref
      185
      %%EOF
    PDF

    File.write(temp_path, pdf_content)
    temp_path.to_s
  end
end
