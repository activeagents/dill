require "test_helper"

class Section::PositionableTest < ActiveSupport::TestCase
  setup do
    @sections = reports(:handbook).sections.positioned
  end

  test "items are sorted in positioned order" do
    assert_equal [ sections(:welcome_section), sections(:welcome_page), sections(:summary_page), sections(:reading_picture) ], @sections
  end

  test "items can be moved earlier" do
    sections(:welcome_page).move_to_position(0)

    assert_equal [ sections(:welcome_page), sections(:welcome_section), sections(:summary_page), sections(:reading_picture) ], @sections.reload
  end

  test "items can be moved beyond the start, which puts them at the start" do
    sections(:welcome_page).move_to_position(-99)

    assert_equal [ sections(:welcome_page), sections(:welcome_section), sections(:summary_page), sections(:reading_picture) ], @sections.reload
  end

  test "items can be moved later" do
    sections(:welcome_section).move_to_position(2)

    assert_equal [ sections(:welcome_page), sections(:summary_page), sections(:welcome_section), sections(:reading_picture) ], @sections.reload
  end

  test "items can be moved beyond the end, which puts them at the end" do
    sections(:welcome_section).move_to_position(99)

    assert_equal [ sections(:welcome_page), sections(:summary_page), sections(:reading_picture), sections(:welcome_section) ], @sections.reload
  end

  test "items can be moved to their existing position" do
    sections(:welcome_page).move_to_position(1)

    assert_equal [ sections(:welcome_section), sections(:welcome_page), sections(:summary_page), sections(:reading_picture) ], @sections.reload
  end

  test "items can be moved in blocks" do
    sections(:welcome_section).move_to_position(1, followed_by: [ sections(:welcome_page), sections(:summary_page) ])

    assert_equal [ sections(:reading_picture), sections(:welcome_section), sections(:welcome_page), sections(:summary_page) ], @sections.reload
  end

  test "new items are inserted at the end" do
    new_page = reports(:handbook).press Page.new(body: "New Page"), title: "New Page"

    assert_equal new_page, reports(:handbook).sections.positioned.last
  end

  test "the first item in the collection has the expected score" do
    reports(:handbook).sections.destroy_all
    new_page = reports(:handbook).press Page.new(body: "New Page"), title: "New Page"

    assert_equal 1, new_page.position_score
  end

  test "positioning is rebalanced when necessary" do
    sections(:welcome_section).update!(position_score: 1e-11)
    sections(:welcome_page).update!(position_score: 2e-11)

    sections(:summary_page).move_to_position(1)

    assert_equal sections(:summary_page), @sections.reload.second
    assert_equal [ 1, 2, 3, 4 ], @sections.pluck(:position_score)
  end

  test "items know their neighbours" do
    assert_equal sections(:welcome_section), sections(:welcome_page).previous
    assert_equal sections(:summary_page), sections(:welcome_page).next

    assert_nil sections(:welcome_section).previous
    assert_nil sections(:reading_picture).next
  end

  test "only active items are included as neighbours" do
    assert_equal sections(:summary_page), sections(:welcome_page).next

    sections(:summary_page).trashed!

    assert_equal sections(:reading_picture), sections(:welcome_page).next
  end

  test "only active items are counted when determining position" do
    sections(:welcome_page).trashed!

    sections(:welcome_section).move_to_position(1)
    assert_equal [ sections(:summary_page), sections(:welcome_section), sections(:reading_picture) ], @sections.reload.active

    sections(:welcome_section).move_to_position(0)
    assert_equal [ sections(:welcome_section), sections(:summary_page), sections(:reading_picture) ], @sections.reload.active
  end
end
