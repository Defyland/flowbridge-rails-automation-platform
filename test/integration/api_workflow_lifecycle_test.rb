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

  test "recovers a queued execution after webhook enqueue fails post-commit" do
    post "/api/v1/organizations",
      params: { organization: { name: "FlowBridge Recovery" } },
      as: :json

    assert_response :created
    token = json_response.dig("api_key", "token")

    post "/api/v1/workflows",
      params: { workflow: { name: "Recovery Flow", description: "Recover enqueue boundary failures" } },
      headers: auth_headers(token),
      as: :json

    assert_response :created
    workflow_id = json_response.dig("workflow", "id")

    with_test_http_endpoint(status: 202, body: { accepted: true, upstream_id: "crm-recovery" }) do |url, requests|
      post "/api/v1/workflows/#{workflow_id}/versions",
        params: { workflow_version: { graph: sample_graph(url: url), retry_policy: { max_attempts: 2 } } },
        headers: auth_headers(token),
        as: :json

      assert_response :created
      trigger_key = json_response.dig("workflow_version", "trigger_key")
      webhook_secret = json_response.fetch("webhook_secret")
      raw_payload = JSON.generate({ email: "recovery@example.com", plan: "scale" })

      enqueue_failure = Class.new(StandardError)

      original_perform_later = WorkflowExecutionJob.method(:perform_later)
      WorkflowExecutionJob.define_singleton_method(:perform_later) do |*|
        raise enqueue_failure, "queue unavailable"
      end

      begin
        assert_raises(enqueue_failure) do
          post "/api/v1/webhooks/#{trigger_key}",
            params: raw_payload,
            headers: {
              "Content-Type" => "application/json",
              "X-FlowBridge-Event-Id" => "evt-api-recovery",
              "X-FlowBridge-Signature" => FlowBridge::SignatureVerifier.signature(secret: webhook_secret, payload: raw_payload),
              "X-Correlation-Id" => "corr-api-recovery"
            }
        end
      ensure
        WorkflowExecutionJob.define_singleton_method(:perform_later, original_perform_later)
      end

      execution = WorkflowExecution.find_by!(idempotency_key: "evt-api-recovery")
      assert_equal "queued", execution.status
      assert_equal 0, execution.attempt_count

      travel_to 3.minutes.from_now do
        assert_enqueued_with(job: WorkflowExecutionJob, args: [ execution.id ]) do
          RecoverQueuedWorkflowExecutionsJob.perform_now
        end
      end

      perform_enqueued_jobs

      assert_equal "succeeded", execution.reload.status
      assert_equal 1, requests.size
    end
  end
end
