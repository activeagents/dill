source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", github: "rails/rails"

# Drivers
gem "sqlite3", "~> 2.2"
gem "pg", "~> 1.5"  # PostgreSQL for staging/production (Cloud SQL)
gem "redis", ">= 4.0.1"
gem "connection_pool", "~> 2.5"  # Pin to 2.x for Rails edge compatibility

# Cloud Storage
gem "google-cloud-storage", "~> 1.47"  # GCS for ActiveStorage in staging/production

# Deployment
gem "puma", ">= 5.0"
gem "bootsnap", require: false

# Jobs
gem "solid_queue"
gem "mission_control-jobs"

# Front-end
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

# Other
gem "jbuilder"
gem "redcarpet", "~> 3.6"
gem "rouge", "~> 4.5"
gem "bcrypt", "~> 3.1.7"
gem "omniauth", "~> 2.1"
gem "omniauth-google-oauth2", "~> 1.1"
gem "omniauth-rails_csrf_protection", "~> 1.0"
gem "image_processing", "~> 1.13"
gem "rqrcode"
gem "thruster"
gem "useragent", github: "basecamp/useragent"
gem "front_matter_parser"

group :development, :test do
  gem "debug"
  gem "faker", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "minitest", "~> 5.0"  # Pin to 5.x; Minitest 6.0 breaks Rails 8.2 alpha LineFiltering
end

group :development do
  gem "web-console"
end

group :test do
  gem "selenium-webdriver"
  gem "capybara-playwright-driver"  # Playwright driver for Capybara
end

gem "reactionview", "~> 0.1.2"

# AI Integration
gem "activeagent", github: "activeagents/activeagent"  # Use main for Gemini provider support
gem "solid_agent", github: "activeagents/solid_agent"
gem "openai"
gem "ruby-anthropic"  # For Anthropic/Claude support
gem "pdf-reader"  # For PDF analysis
gem "capybara"  # Browser automation for research agent
gem "cuprite"  # Headless Chrome driver for web browsing
