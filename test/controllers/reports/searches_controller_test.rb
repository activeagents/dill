require "test_helper"

class Reports::SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin

    Section.reindex_all
  end

  test "create finds matching pages" do
    post report_search_url(reports(:handbook)), params: { search: "Thanks" }

    assert_response :success
    assert_select "a", text: /Thanks for reading/i
  end

  test "create allows searching published reports without being logged in" do
    sign_out
    reports(:handbook).update!(published: true)

    post report_search_url(reports(:handbook)), params: { search: "Thanks" }
    assert_response :success

    reports(:handbook).update!(published: false)

    post report_search_url(reports(:handbook)), params: { search: "Thanks" }
    assert_response :not_found
  end

  test "create shows when there are no matches" do
    post report_search_url(reports(:handbook)), params: { search: "the invisible man" }

    assert_response :success
    assert_select "p", text: /no matches/i
  end

  test "create shows no matches when the search has only ignored characters" do
    post report_search_url(reports(:handbook)), params: { search: "^$" }

    assert_response :success
    assert_select "p", text: /no matches/i
  end

  test "create does not find trashed pages" do
    sections(:summary_page).trashed!

    post report_search_url(reports(:handbook)), params: { search: "Thanks" }

    assert_response :success
    assert_select "p", text: /no matches/i
  end
end
