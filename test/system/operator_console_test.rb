require "application_system_test_case"

class OperatorConsoleTest < ApplicationSystemTestCase
  setup do
    @organization = organizations(:flowbridge)
    @user = users(:one)
    @workflow_version = publish_workflow_version(organization: @organization)
    @execution = @workflow_version.workflow_executions.create!(
      organization: @organization,
      workflow: @workflow_version.workflow,
      status: "failed",
      attempt_count: 2,
      idempotency_key: "system-event-1",
      correlation_id: "system-correlation-1",
      input_json: { "email" => "system@example.com" },
      error_json: { "code" => "http_transient_failure" },
      started_at: 2.minutes.ago,
      completed_at: 1.minute.ago
    )
    @node_execution = @execution.node_executions.create!(
      node_key: "sync_crm",
      node_type: "http_request",
      status: "failed",
      attempt: 2,
      input_json: {},
      error_json: { "code" => "http_transient_failure" },
      started_at: 2.minutes.ago,
      completed_at: 1.minute.ago,
      duration_ms: 40
    )
    @dead_letter = @organization.dead_letters.create!(
      workflow_execution: @execution,
      node_execution: @node_execution,
      reason: "http_transient_failure",
      payload_json: { "node" => "sync_crm" }
    )
  end

  test "operator signs in and resolves a dead letter" do
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_on "Sign in"

    assert_text "Operations overview"
    click_on "Dead letters"
    click_on @dead_letter.id.to_s
    click_on "Resolve"

    assert_text "Dead letter resolved"
    assert_text "Resolved"
  end
end
