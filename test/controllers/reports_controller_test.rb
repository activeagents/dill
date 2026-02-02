require "test_helper"

class BooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
  end

  test "index lists the current user's reports" do
    get root_url

    assert_response :success
    assert_select "h2", text: "Handbook"
    assert_select "h2", text: "Manual", count: 0
  end

  test "index includes published reports, even when the user does not have access" do
    reports(:manual).update!(published: true)

    get root_url

    assert_response :success
    assert_select "h2", text: "Handbook"
    assert_select "h2", text: "Manual"
  end

  test "index shows published reports when not logged in" do
    reports(:manual).update!(published: true)

    sign_out
    get root_url

    assert_response :success
    assert_select "h2", text: "Handbook", count: 0
    assert_select "h2", text: "Manual"
  end

  test "index redirects to login if not signed in and no published reports exist" do
    sign_out
    get root_url

    assert_redirected_to new_session_url
  end

  test "create makes the current user an editor" do
    assert_difference -> { Report.count }, +1 do
      post reports_url, params: { report: { title: "New Report", everyone_access: false } }
    end

    assert_redirected_to report_slug_url(Report.last)

    report = Report.last
    assert_equal "New Report", report.title
    assert_equal 1, Report.last.accesses.count

    assert report.editable?(user: users(:kevin))
  end

  test "create sets additional accesses" do
    sign_in :jason
    assert_difference -> { Report.count }, +1 do
      post reports_url, params: { report: { title: "New Report", everyone_access: false }, "editor_ids[]": users(:jz).id, "reader_ids[]": users(:kevin).id }
    end

    report = Report.last
    assert_equal "New Report", report.title
    assert_equal 3, Report.last.accesses.count

    assert report.editable?(user: users(:jz))

    assert report.accessable?(user: users(:kevin))
    assert_not report.editable?(user: users(:kevin))
  end

  test "show only shows reports the current user can access" do
    get report_slug_url(reports(:manual))
    assert_response :not_found

    get report_slug_url(reports(:handbook))
    assert_response :success
  end

  test "show includes OG metadata for public access" do
    get report_slug_url(reports(:handbook))
    assert_response :success

    assert_select "meta[property='og:title'][content='Handbook']"
    assert_select "meta[property='og:url'][content='#{report_slug_url(reports(:handbook))}']"
  end
end
