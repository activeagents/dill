require "test_helper"

class Report::AccessableTest < ActiveSupport::TestCase
  test "update_access always grants read access to everyone when everyone_access is set" do
    report = Report.create!(title: "My new report")
    report.update_access(editors: [], readers: [])

    assert report.everyone_access?

    User.all.each do |user|
      assert report.accessable?(user: user)
      assert_not report.editable?(user: user) unless user.administrator?
    end
  end

  test "update_access updates existing access" do
    report = Report.create!(title: "My new report", everyone_access: false)

    report.update_access(editors: [ users(:kevin).id ], readers: [])
    assert report.editable?(user: users(:kevin))

    report.update_access(editors: [], readers: [ users(:kevin).id ])
    assert report.accessable?(user: users(:kevin))
    assert_not report.editable?(user: users(:kevin))
  end

  test "update_access removes stale accesses" do
    report = Report.create!(title: "My new report", everyone_access: false)

    report.update_access(editors: [ users(:kevin).id ], readers: [ users(:jz).id ])
    assert_equal 2, report.accesses.size

    report.update_access(editors: [ users(:kevin).id ], readers: [])
    assert_equal 1, report.accesses.size
  end
end
