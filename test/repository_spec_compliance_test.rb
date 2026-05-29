require "test_helper"
require "yaml"

class RepositorySpecComplianceTest < ActiveSupport::TestCase
  REQUIRED_README_SECTIONS = [
    "What is this product?",
    "Problem it solves",
    "Target users",
    "Main features",
    "Architecture overview",
    "Tech stack",
    "Domain model",
    "API documentation",
    "Async or event architecture",
    "Database design",
    "Testing strategy",
    "Performance benchmarks",
    "Observability",
    "Security considerations",
    "Trade-offs and decisions",
    "How to run locally",
    "How to run tests",
    "Failure scenarios",
    "Roadmap"
  ].freeze

  test "mandatory repository structure and product documentation are present" do
    %w[
      docs/adr
      docs/architecture
      docs/benchmarks
      docs/api
      docs/diagrams
      docs/runbooks
      benchmarks/results
    ].each do |path|
      assert Rails.root.join(path).directory?, "#{path} should exist"
    end

    readme = Rails.root.join("README.md").read
    REQUIRED_README_SECTIONS.each do |section|
      assert_includes readme, "## #{section}"
    end
  end

  test "openapi contract documents versioned core endpoints and error format" do
    contract = YAML.load_file(Rails.root.join("openapi.yaml"))

    assert_equal "3.1.0", contract.fetch("openapi")
    assert contract.fetch("paths").key?("/api/v1/workflows")
    assert contract.fetch("paths").key?("/api/v1/webhooks/{trigger_key}")
    assert contract.dig("components", "schemas", "ErrorResponse")
  end
end
