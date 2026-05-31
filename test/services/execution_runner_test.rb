require "test_helper"

class ExecutionRunnerTest < ActiveSupport::TestCase
  test "executes workflow nodes and records node-level evidence" do
    organization, = create_organization_with_key
    with_test_http_endpoint(status: 202, body: { accepted: true }) do |url, requests|
      version = publish_workflow_version(organization: organization, graph: sample_graph(url: url))
      execution = version.workflow_executions.create!(
        organization: organization,
        workflow: version.workflow,
        idempotency_key: "evt-success",
        correlation_id: "corr-success",
        input_json: { "email" => "buyer@example.com" }
      )

      FlowBridge::ExecutionRunner.new(execution).call

      assert_equal "succeeded", execution.reload.status
      assert_equal 1, execution.attempt_count
      assert_equal %w[incoming_webhook normalize sync_crm], execution.node_executions.order(:created_at).pluck(:node_key)
      assert_equal 0, organization.dead_letters.count
      assert_equal 1, requests.size
    end
  end

  test "retries transient failures and dead-letters after policy exhaustion" do
    organization, = create_organization_with_key
    with_test_http_endpoint(status: 503, body: { error: "transient" }) do |url, requests|
      version = publish_workflow_version(
        organization: organization,
        graph: sample_graph(url: url),
        retry_policy: { "max_attempts" => 2, "base_delay_seconds" => 0, "jitter_seconds" => 0 }
      )
      execution = version.workflow_executions.create!(
        organization: organization,
        workflow: version.workflow,
        idempotency_key: "evt-fail",
        correlation_id: "corr-fail",
        input_json: { "email" => "buyer@example.com" }
      )

      FlowBridge::ExecutionRunner.new(execution).call
      assert_equal "retrying", execution.reload.status
      assert_equal 0, organization.dead_letters.count

      FlowBridge::ExecutionRunner.new(execution.reload).call
      assert_equal "failed", execution.reload.status
      assert_equal 2, execution.attempt_count
      assert_equal 2, requests.size
      assert_equal 1, organization.dead_letters.where(reason: "http_transient_failure").count
    end
  end

  test "does not start a duplicate attempt while an execution is actively running" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)
    execution = version.workflow_executions.create!(
      organization: organization,
      workflow: version.workflow,
      status: "running",
      started_at: Time.current,
      idempotency_key: "evt-running",
      correlation_id: "corr-running",
      input_json: { "email" => "running@example.com" }
    )

    assert_no_changes -> { execution.reload.attempt_count } do
      FlowBridge::ExecutionRunner.new(execution).call
    end
    assert_equal 0, execution.node_executions.count
  end
end
