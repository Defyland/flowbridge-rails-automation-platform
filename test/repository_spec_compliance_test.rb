require "test_helper"
require "json"
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
      docs/api
      docs/architecture
      docs/benchmarks
      docs/domain
      docs/diagrams
      docs/events
      docs/product
      docs/runbooks
      docs/security
      docs/spec-driven
      benchmarks/results
    ].each do |path|
      assert Rails.root.join(path).directory?, "#{path} should exist"
    end

    %w[
      docs/engineering-case-study.md
      docs/observability.md
      docs/scalability.md
      docs/operational-cost.md
      docs/testing-strategy.md
      docs/spec-driven/senior-readiness-spec.md
      docs/spec-driven/techlead-hardening-spec.md
      docs/spec-driven/implementation-plan.md
      docs/spec-driven/verification-report.md
      docs/product/problem.md
      docs/product/personas.md
      docs/product/use-cases.md
      docs/product/non-goals.md
      docs/product/roadmap.md
      docs/product/pricing-or-plans.md
      docs/domain/glossary.md
      docs/domain/bounded-contexts.md
      docs/domain/aggregates.md
      docs/domain/invariants.md
      docs/domain/state-machines.md
      docs/architecture/c4-context.md
      docs/architecture/c4-container.md
      docs/architecture/module-boundaries.md
      docs/architecture/sequence-diagrams.md
      docs/architecture/deployment-view.md
      docs/security/threat-model.md
      docs/security/authorization-matrix.md
      docs/security/data-classification.md
      docs/security/secrets.md
      docs/security/abuse-cases.md
    ].each do |path|
      assert Rails.root.join(path).file?, "#{path} should exist"
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

  test "event contracts are documented as parseable json schemas" do
    event_docs = Rails.root.join("docs/events")
    schemas = event_docs.glob("*.v1.json")

    assert_operator schemas.count, :>=, 5

    schemas.each do |schema_path|
      schema = JSON.parse(schema_path.read)

      assert_equal "https://json-schema.org/draft/2020-12/schema", schema.fetch("$schema")
      assert schema.dig("properties", "event_id"), "#{schema_path} should document event_id"
      assert schema.dig("properties", "event_type"), "#{schema_path} should document event_type"
      assert schema.dig("properties", "schema_version"), "#{schema_path} should document schema_version"
      assert schema.dig("properties", "correlation_id"), "#{schema_path} should document correlation_id"
    end
  end
end
