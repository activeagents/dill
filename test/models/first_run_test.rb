require "test_helper"

class FirstRunTest < ActiveSupport::TestCase
  setup do
    Report.destroy_all
    User.destroy_all
    Account.destroy_all
  end

  test "creating makes first user an administrator" do
    user = create_first_run_user
    assert user.administrator?
  end

  test "creates an account" do
    assert_changes -> { Account.count }, +1 do
      create_first_run_user
    end
  end

  test "creates a demo report" do
    assert_changes -> { Report.count }, to: 1 do
      create_first_run_user
    end

    report = Report.first

    assert report.editable?(user: User.first)
    assert report.cover.attached?
    assert report.sections.any?
  end

  private
    def create_first_run_user
      FirstRun.create!({ name: "User", email_address: "user@example.com", password: "secret123456" })
    end
end
