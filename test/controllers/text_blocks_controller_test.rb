require "test_helper"

class SectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
  end

  test "create" do
    post report_sections_path(reports(:handbook), format: :turbo_stream)
    assert_response :success

    new_section = Section.last
    assert_equal "Section", new_section.title
    assert_equal reports(:handbook), new_section.section.report
  end

  test "update" do
    put leafable_path(sections(:welcome_section)), params: {
      section: { title: "Title" },
      section: { body: "Section body" }
    }
    assert_response :success

    section = sections(:welcome_section).reload.sectionable
    assert_equal "Title", section.title
    assert_equal "Section body", section.body
  end

  test "update with no body supplied" do
    put leafable_path(sections(:welcome_section)), params: { section: { title: "New title" } }
    assert_response :success

    section = sections(:welcome_section).reload.sectionable
    assert_equal "New title", section.title
    assert_equal "New title", section.body
  end
end
