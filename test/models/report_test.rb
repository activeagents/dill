require "test_helper"

class BookTest < ActiveSupport::TestCase
  test "slug is generated from title" do
    report = Report.create!(title: "Hello, World!")
    assert_equal "hello-world", report.slug
  end

  test "press a sectionable" do
    section = reports(:manual).press Page.new(body: "Important words"), title: "Introduction"

    assert section.page?
    assert_equal "Important words", section.page.body.content.to_s
    assert_equal "Introduction", section.title
  end
end
