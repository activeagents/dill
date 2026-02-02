require "test_helper"

class Reports::PublicationsTest < ActionDispatch::IntegrationTest
  setup do
    @report = reports(:manual)

    sign_in :david
  end

  test "publish a report" do
    assert_changes -> { @report.reload.published? }, from: false, to: true do
      patch report_publication_url(@report), params: { report: { published: "1" } }
    end

    @report.reload
    assert_redirected_to report_slug_url(@report)
    assert_equal "manual", @report.slug
  end

  test "edit report slug" do
    @report.update! published: true

    get edit_report_publication_url(@report)
    assert_response :success

    patch report_publication_url(@report), params: { report: { slug: "new-slug" } }

    @report.reload
    assert_redirected_to report_slug_url(@report)
    assert_equal "new-slug", @report.slug
  end
end
