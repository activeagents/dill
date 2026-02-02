require "test_helper"

class LeafTest < ActiveSupport::TestCase
  test "slug is generated from title" do
    section = Section.new(title: "Hello, World!")
    assert_equal "hello-world", section.slug
  end

  test "slug is never completely blank" do
    section = Section.new(title: "")
    assert_equal "-", section.slug
  end
end
