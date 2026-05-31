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

  test "rate limits public organization bootstrap and ignores client supplied plan limits" do
    with_env("FLOWBRIDGE_BOOTSTRAP_ORG_LIMIT_PER_HOUR" => "1") do
      post "/api/v1/organizations",
        params: { organization: { name: "Bootstrap One", plan: "enterprise", rate_limit_per_minute: 10_000 } },
        as: :json

      assert_response :created
      organization_id = json_response.dig("organization", "id")
      assert_equal "launch", Organization.find(organization_id).plan
      assert_equal 120, Organization.find(organization_id).rate_limit_per_minute

      post "/api/v1/organizations",
        params: { organization: { name: "Bootstrap Two" } },
        as: :json

      assert_response :too_many_requests
      assert_equal "rate_limited", json_response.dig("error", "code")
    end
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
