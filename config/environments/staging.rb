require "active_support/core_ext/integer/time"
require "active_support/core_ext/numeric/bytes"

Rails.application.configure do
  # Staging is essentially production with more verbose logging for debugging

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Store uploaded files in Google Cloud Storage (see config/storage.yml for options).
  config.active_storage.service = :google

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # More verbose logging for staging debugging
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "debug")

  # Cache in Redis
  config.cache_store = :redis_cache_store

  # Assets are cacheable
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # Enable locale fallbacks for I18n
  config.i18n.fallbacks = true

  # Always be SSL'ing (unless told not to)
  config.assume_ssl = ENV["DISABLE_SSL"].blank?
  config.force_ssl  = ENV["DISABLE_SSL"].blank?

  # Report deprecations in staging so we catch them before production
  config.active_support.report_deprecations = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Use SolidQueue with PostgreSQL
  config.active_job.queue_adapter = :solid_queue
end
