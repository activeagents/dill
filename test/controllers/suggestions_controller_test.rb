require "test_helper"

class SuggestionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :kevin
    @page = Page.create!(body: "The quick brown fox jumps over the lazy dog.")
    @suggestion = @page.suggestions.create!(
      suggestion_type: "edit",
      original_text: "quick brown fox",
      suggested_text: "swift red fox",
      ai_generated: true
    )
  end

  test "accept via JSON applies suggestion content to page body" do
    patch accept_suggestion_path(@suggestion), headers: { "Accept" => "application/json" }

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "accepted", json["status"]

    @page.reload
    assert_equal "The swift red fox jumps over the lazy dog.", @page.body.content
  end

  test "accept via HTML redirects and applies content" do
    patch accept_suggestion_path(@suggestion)

    assert_response :redirect
    @page.reload
    assert_equal "The swift red fox jumps over the lazy dog.", @page.body.content
  end

  test "reject via JSON does not modify page body" do
    patch reject_suggestion_path(@suggestion), headers: { "Accept" => "application/json" }

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "rejected", json["status"]

    @page.reload
    assert_equal "The quick brown fox jumps over the lazy dog.", @page.body.content
  end
end
