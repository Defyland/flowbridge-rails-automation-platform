require "test_helper"

class RateLimitingAndMetricsTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  test "rate limits authenticated API keys per minute" do
    organization, _key, token = create_organization_with_key(rate_limit_per_minute: 1)

    get "/api/v1/organizations/#{organization.id}", headers: auth_headers(token), as: :json
    assert_response :success

    get "/api/v1/organizations/#{organization.id}", headers: auth_headers(token), as: :json
    assert_response :too_many_requests
    assert_equal "rate_limited", json_response.dig("error", "code")
  end

  test "exports prometheus metrics for executions, events, and dead letters" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)
    execution = version.workflow_executions.create!(
      organization: organization,
      workflow: version.workflow,
      status: "failed",
      idempotency_key: "evt-metrics",
      correlation_id: "corr-metrics",
      input_json: {}
    )
    organization.dead_letters.create!(workflow_execution: execution, reason: "test_failure")

    get "/metrics"

    assert_response :success
    assert_includes response.body, 'flowbridge_workflow_executions_total{status="failed"} 1'
    assert_includes response.body, "flowbridge_dead_letters_open 1"
  end
end
