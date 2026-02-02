require "test_helper"

class Reports::BookmarksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
  end

  test "show includes a link to read the last read section" do
    cookies["reading_progress_#{reports(:handbook).id}"] = "#{sections(:welcome_page).id}/3"

    get report_bookmark_url(reports(:handbook))

    assert_response :success
    assert_select "a", /Resume reading/
  end

  test "show includes a link to start reading if the last read section has been trashed" do
    sections(:welcome_page).trashed!
    cookies["reading_progress_#{reports(:handbook).id}"] = "#{sections(:welcome_page).id}/3"

    get report_bookmark_url(reports(:handbook))

    assert_response :success
    assert_select "a", /Start reading/
  end

  test "show includes a link to start reading if no reading progress has been recorded" do
    get report_bookmark_url(reports(:handbook))

    assert_response :success
    assert_select "a", /Start reading/
  end
end
