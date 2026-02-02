require "test_helper"

class LeafablesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
  end

  test "show" do
    get leafable_slug_path(sections(:welcome_page))

    assert_response :success
    assert_select "p", "This is such a great handbook."
  end

  test "show with public access to a published report" do
    sign_out
    reports(:handbook).update!(published: true)

    get leafable_slug_path(sections(:welcome_page))

    assert_response :success
    assert_select "p", "This is such a great handbook."
  end

  test "show highlights search terms" do
    Section.reindex_all
    get leafable_slug_path(sections(:welcome_page)), params: { search: "great" }

    assert_response :success
    assert_select "mark", "great"
  end

  test "show does not allow public access to an unpublished report" do
    sign_out

    get leafable_slug_path(sections(:welcome_page))

    assert_response :not_found
  end

  test "create" do
    assert_changes -> { reports(:handbook).sections.count }, +1 do
      post report_pages_path(reports(:handbook), format: :turbo_stream), params: {
        section: { title: "Another page" }, page: { body: "With interesting words." }
      }
    end

    assert_response :success
  end

  test "create requires editor access" do
    reports(:handbook).access_for(user: users(:kevin)).update! level: :reader

    assert_no_changes -> { reports(:handbook).sections.count } do
      post report_pages_path(reports(:handbook), format: :turbo_stream), params: {
        section: { title: "Another page" }, page: { body: "With interesting words." }
      }
    end

    assert_response :forbidden
  end
end
