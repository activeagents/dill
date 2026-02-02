ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Register Playwright driver for Capybara if the gem is available
begin
  require "capybara/playwright"

  # Register a custom Playwright driver (Rails 6.1+ reserves :playwright name)
  Capybara.register_driver(:capybara_playwright) do |app|
    Capybara::Playwright::Driver.new(app,
      browser_type: :chromium,
      headless: ENV.fetch("PLAYWRIGHT_HEADLESS", "true") == "true"
    )
  end
rescue LoadError
  # capybara-playwright-driver not installed, Playwright tests will be skipped
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include SessionTestHelper
  end
end
