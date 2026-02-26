require "test_helper"

class TextBlocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
  end

  test "create" do
    post report_text_blocks_path(reports(:handbook), format: :turbo_stream)
    assert_response :success

    new_text_block = TextBlock.last
    assert_equal "Text block", new_text_block.title
    assert_equal reports(:handbook), new_text_block.section.report
  end

  test "update" do
    put sectionable_path(sections(:welcome_text_block)), params: {
      section: { title: "Title" },
      text_block: { body: "Section body" }
    }
    assert_response :success

    sections(:welcome_text_block).reload
    assert_equal "Title", sections(:welcome_text_block).title
    assert_equal "Section body", sections(:welcome_text_block).sectionable.body
  end

  test "update with no body supplied" do
    put sectionable_path(sections(:welcome_text_block)), params: { section: { title: "New title" } }
    assert_response :success

    sections(:welcome_text_block).reload
    assert_equal "New title", sections(:welcome_text_block).title
    assert_equal "New title", sections(:welcome_text_block).sectionable.body
  end
end
