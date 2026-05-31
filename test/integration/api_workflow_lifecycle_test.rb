require "test_helper"

class ApiWorkflowLifecycleTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "creates organization, publishes workflow version, ingests webhook, and executes asynchronously" do
    post "/api/v1/organizations",
      params: { organization: { name: "FlowBridge Demo" } },
      as: :json

    assert_response :created
    token = json_response.dig("api_key", "token")

    post "/api/v1/workflows",
      params: { workflow: { name: "Lead Intake", description: "Sync signed-up leads into CRM" } },
      headers: auth_headers(token),
      as: :json

    assert_response :created
    workflow_id = json_response.dig("workflow", "id")

    with_test_http_endpoint(status: 202, body: { accepted: true, upstream_id: "crm-1" }) do |url, requests|
      post "/api/v1/workflows/#{workflow_id}/versions",
        params: { workflow_version: { graph: sample_graph(url: url), retry_policy: { max_attempts: 2 } } },
        headers: auth_headers(token),
        as: :json

      assert_response :created
      trigger_key = json_response.dig("workflow_version", "trigger_key")
      webhook_secret = json_response.fetch("webhook_secret")
      raw_payload = JSON.generate({ email: "buyer@example.com", plan: "scale" })

      assert_enqueued_with(job: WorkflowExecutionJob) do
        post "/api/v1/webhooks/#{trigger_key}",
          params: raw_payload,
          headers: {
            "Content-Type" => "application/json",
            "X-FlowBridge-Event-Id" => "evt-api-success",
            "X-FlowBridge-Signature" => FlowBridge::SignatureVerifier.signature(secret: webhook_secret, payload: raw_payload),
            "X-Correlation-Id" => "corr-api-success"
          }
      end

      assert_response :accepted
      execution_id = json_response.dig("workflow_execution", "id")
      perform_enqueued_jobs

      get "/api/v1/executions/#{execution_id}", headers: auth_headers(token), as: :json
      assert_response :success
      assert_equal "succeeded", json_response.dig("workflow_execution", "status")
      assert_equal 3, json_response.dig("workflow_execution", "nodes").size
      assert_equal 1, requests.size
    end
  end
end
