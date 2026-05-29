ENV["RAILS_ENV"] ||= "test"
ENV["FLOWBRIDGE_DISABLE_RETRY_DELAY"] = "true"

require "simplecov"
SimpleCov.start "rails"

require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "support/api_test_helper"

module ActiveSupport
  class TestCase
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include ApiTestHelper
  end
end
