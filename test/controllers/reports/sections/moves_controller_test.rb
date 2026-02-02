require "test_helper"

class Reports::Sections::MovesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
  end

  test "moving a single item" do
    assert_equal [ sections(:welcome_section), sections(:welcome_page), sections(:summary_page), sections(:reading_picture) ], reports(:handbook).sections.positioned

    post report_sections_moves_url(reports(:handbook), id: sections(:welcome_page).id, position: 0)
    assert_response :no_content

    assert_equal [ sections(:welcome_page), sections(:welcome_section), sections(:summary_page), sections(:reading_picture) ], reports(:handbook).sections.positioned
  end

  test "moving multiple items" do
    assert_equal [ sections(:welcome_section), sections(:welcome_page), sections(:summary_page), sections(:reading_picture) ], reports(:handbook).sections.positioned

    post report_sections_moves_url(reports(:handbook), id: sections(:summary_page, :reading_picture).map(&:id), position: 1)
    assert_response :no_content

    assert_equal [ sections(:welcome_section), sections(:summary_page), sections(:reading_picture), sections(:welcome_page) ], reports(:handbook).sections.positioned
  end
end
