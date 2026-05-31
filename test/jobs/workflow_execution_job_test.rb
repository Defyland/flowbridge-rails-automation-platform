require "test_helper"

class WorkflowExecutionJobTest < ActiveJob::TestCase
  test "performs a queued execution" do
    organization, = create_organization_with_key
    with_test_http_endpoint(status: 202, body: { accepted: true }) do |url, requests|
      version = publish_workflow_version(organization: organization, graph: sample_graph(url: url))
      execution = version.workflow_executions.create!(
        organization: organization,
        workflow: version.workflow,
        idempotency_key: "evt-job",
        correlation_id: "corr-job",
        input_json: { "email" => "job@example.com" }
      )

      WorkflowExecutionJob.perform_now(execution.id)

      assert_equal "succeeded", execution.reload.status
      assert_equal 1, requests.size
    end
  end
end
