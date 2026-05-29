source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
gem "pg", ">= 1.5"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
gem "thruster", require: false

gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1"

gem "solid_queue"
gem "solid_cache"
gem "solid_cable"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

gem "opentelemetry-api"
gem "opentelemetry-exporter-otlp"
gem "opentelemetry-instrumentation-action_pack"
gem "opentelemetry-instrumentation-active_job"
gem "opentelemetry-instrumentation-active_record"
gem "opentelemetry-instrumentation-rack"
gem "opentelemetry-sdk"
gem "kamal", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  gem "simplecov", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
