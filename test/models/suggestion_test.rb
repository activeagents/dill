require "test_helper"

class SuggestionTest < ActiveSupport::TestCase
  test "accept edit suggestion applies content to page body" do
    page = Page.new(body: "Welcome to the handbook for new employees.")
    page.save!

    suggestion = page.suggestions.create!(
      suggestion_type: "edit",
      original_text: "Welcome to the handbook",
      suggested_text: "Welcome to our comprehensive handbook",
      ai_generated: true
    )

    suggestion.accept!

    page.reload
    assert_equal "Welcome to our comprehensive handbook for new employees.", page.body.content
    assert suggestion.accepted?
  end

  test "accept edit suggestion sets resolved metadata" do
    page = Page.new(body: "Some content here.")
    page.save!

    suggestion = page.suggestions.create!(
      suggestion_type: "edit",
      original_text: "Some content",
      suggested_text: "Better content",
      ai_generated: true
    )

    user = users(:kevin)
    suggestion.accept!(user)

    assert suggestion.accepted?
    assert_equal user, suggestion.resolved_by
    assert_not_nil suggestion.resolved_at
  end

  test "accept edit suggestion rolls back on failure" do
    page = Page.new(body: "Actual content here.")
    page.save!

    suggestion = page.suggestions.create!(
      suggestion_type: "edit",
      original_text: "text that does not exist in body",
      suggested_text: "replacement text",
      ai_generated: true
    )

    assert_raises(ActiveRecord::RecordNotSaved) do
      suggestion.accept!
    end

    suggestion.reload
    assert suggestion.pending?, "Suggestion should remain pending after failed accept"
  end

  test "accept comment suggestion does not modify page body" do
    page = Page.new(body: "Original content stays the same.")
    page.save!

    suggestion = page.suggestions.create!(
      suggestion_type: "comment",
      comment: "This section needs work",
      ai_generated: true
    )

    suggestion.accept!

    page.reload
    assert_equal "Original content stays the same.", page.body.content
    assert suggestion.accepted?
  end

  test "reject does not modify page body" do
    page = Page.new(body: "Content should not change.")
    page.save!

    suggestion = page.suggestions.create!(
      suggestion_type: "edit",
      original_text: "Content should not change",
      suggested_text: "This should never appear",
      ai_generated: true
    )

    suggestion.reject!(users(:kevin))

    page.reload
    assert_equal "Content should not change.", page.body.content
    assert suggestion.rejected?
  end

  test "accept only replaces first occurrence" do
    page = Page.new(body: "the cat and the cat sat on the mat")
    page.save!

    suggestion = page.suggestions.create!(
      suggestion_type: "edit",
      original_text: "the cat",
      suggested_text: "the dog",
      ai_generated: true
    )

    suggestion.accept!

    page.reload
    assert_equal "the dog and the cat sat on the mat", page.body.content
  end
end
