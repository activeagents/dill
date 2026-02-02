require "test_helper"

# PlaywrightSystemTestCase provides a base class for Playwright-based end-to-end tests.
#
# This test case uses the capybara-playwright-driver gem for browser automation,
# which provides modern browser testing capabilities with better performance
# than Selenium for certain use cases.
#
# Setup:
# 1. Add to Gemfile: gem "capybara-playwright-driver"
# 2. Run: bundle install
# 3. Install Playwright browsers: npx playwright install chromium
#
# If Playwright is not available, tests will fall back to Selenium or skip.
#
class PlaywrightSystemTestCase < ActionDispatch::SystemTestCase
  include SystemTestHelper

  # Dynamically choose driver based on availability
  # Falls back to selenium if Playwright is not available
  if Capybara.drivers.key?(:capybara_playwright)
    driven_by :capybara_playwright, using: :chromium, screen_size: [1400, 1400], options: {
      headless: ENV.fetch("PLAYWRIGHT_HEADLESS", "true") == "true"
    }
  else
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  end

  # Helper to check if Playwright driver is available
  def self.playwright_available?
    Capybara.drivers.key?(:capybara_playwright)
  end

  # Instance method for use in tests
  def playwright_available?
    self.class.playwright_available?
  end

  # Helper to wait for agent processing to complete
  def wait_for_agent_context(max_wait: 30)
    Timeout.timeout(max_wait) do
      loop do
        contexts = AgentContext.where(status: "completed").or(AgentContext.where(status: "failed"))
        break if contexts.any?
        sleep 0.5
      end
    end
  rescue Timeout::Error
    Rails.logger.warn "Timeout waiting for agent context completion"
  end

  # Helper to wait for document processing to complete
  def wait_for_document_processing(document, max_wait: 30)
    Timeout.timeout(max_wait) do
      loop do
        document.reload
        break if document.completed? || document.failed?
        sleep 0.5
      end
    end
  rescue Timeout::Error
    Rails.logger.warn "Timeout waiting for document processing"
  end

  # Helper to wait for ActionCable stream to complete
  def wait_for_stream_completion(stream_id, max_wait: 30)
    Timeout.timeout(max_wait) do
      loop do
        sleep 0.5
        break if page.evaluate_script("window.streamCompleted")
      end
    end
  rescue Timeout::Error
    # Stream may not have completed, but test can continue
    Rails.logger.warn "Timeout waiting for stream completion"
  end

  # Helper to fill content in the house-md editor
  def fill_house_editor(name, content)
    execute_script <<~JS
      const editor = document.querySelector("[name='#{name}']")
      if (editor) {
        editor.value = #{content.to_json}
        editor.dispatchEvent(new Event('input', { bubbles: true }))
      }
    JS
  end
end

