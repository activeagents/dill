require "test_helper"

class Section::EditableTest < ActiveSupport::TestCase
  test "editing a sectionable records the edit" do
    sections(:welcome_page).edit leafable_params: { body: "New body" }

    assert_equal "New body", sections(:welcome_page).page.body.content

    assert sections(:welcome_page).edits.last.revision?
    assert_equal "This is _such_ a great handbook.", sections(:welcome_page).edits.last.page.body.content
  end

  test "edits that are close together don't create new revisions" do
    assert_difference -> { sections(:welcome_page).edits.count }, +1 do
      sections(:welcome_page).edit leafable_params: { body: "First change" }
    end

    freeze_time
    travel 1.minute

    assert_no_difference -> { sections(:welcome_page).edits.count } do
      sections(:welcome_page).edit leafable_params: { body: "Second change" }
    end

    assert_equal "Second change", sections(:welcome_page).page.body.content
    assert_equal Time.now, sections(:welcome_page).edits.last.updated_at

    travel 1.hour

    assert_difference -> { sections(:welcome_page).edits.count }, +1 do
      sections(:welcome_page).edit leafable_params: { body: "Third change" }
    end
  end

  test "changing a section title doesn't create a revision" do
    assert_no_difference -> { Edit.count } do
      sections(:welcome_page).edit section_params: { title: "New title" }
    end

    assert_equal "New title", sections(:welcome_page).title
  end

  test "changes that don't affect the sectionable don't create a revision" do
    assert_no_difference -> { Edit.count } do
      sections(:welcome_page).edit leafable_params: {}
    end
  end

  test "editing a sectionable with an attachment includes the attachments in the new version" do
    assert sections(:reading_picture).picture.image.attached?

    sections(:reading_picture).edit section_params: { title: "New title" }

    assert_equal "New title", sections(:reading_picture).title
    assert sections(:reading_picture).picture.image.attached?
  end

  test "trashing a section records the edit" do
    sections(:welcome_page).trashed!

    assert sections(:welcome_page).trashed?

    assert sections(:welcome_page).edits.last.trash?
    assert_equal "This is _such_ a great handbook.", sections(:welcome_page).edits.last.page.body.content
  end
end
