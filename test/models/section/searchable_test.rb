require "test_helper"

class Section::SearchableTest < ActiveSupport::TestCase
  setup do
    Section.reindex_all
  end

  test "section body is indexed and searchable" do
    sections = Section.search("great handbook")
    assert_includes sections, sections(:welcome_page)
  end

  test "updating a section updates the search index" do
    pages(:welcome).update! body: "sausages"

    sections = Section.search("sausages")
    assert_includes sections, sections(:welcome_page)
  end

  test "search includes highlighted matches" do
    sections = Section.search("great handbook")
    assert_includes sections.first.title_match, "The <mark>Handbook</mark>"
    assert_includes sections.first.content_match, "<mark>great</mark> <mark>handbook</mark>"
  end

  test "sections with no searchable content are not indexed" do
    sections = Section.search("welcome")
    assert_not_includes sections, sections(:welcome_section)
  end

  test "matches_for_highlight returns the matching terms, longest first" do
    matches = sections(:welcome_page).matches_for_highlight("great handbook")
    assert_equal [ "handbook", "great" ], matches
  end

  test "matches_for_highlight is empty when there is no match" do
    markup = sections(:welcome_page).matches_for_highlight("haggis")
    assert_empty markup
  end
end
