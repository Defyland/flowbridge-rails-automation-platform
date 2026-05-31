require "test_helper"

class WorkflowVersionTest < ActiveSupport::TestCase
  test "published versions are immutable execution artifacts" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)

    assert_no_changes -> { version.reload.graph_checksum } do
      assert_not version.update(graph_json: sample_graph(url: "https://example.com/other"))
    end
    assert_includes version.errors[:base], "workflow versions are immutable"
  end

  test "requires a webhook trigger node" do
    organization, = create_organization_with_key
    workflow = organization.workflows.create!(name: "Missing Trigger")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      FlowBridge::WorkflowPublisher.publish!(
        workflow: workflow,
        graph: { "nodes" => [ { "key" => "sync", "type" => "http_request", "config" => { "url" => "https://example.com/ok" } } ] }
      )
    end

    assert_match(/webhook_trigger/, error.message)
  end

  test "rejects unsupported http schemes before publication" do
    organization, = create_organization_with_key
    workflow = organization.workflows.create!(name: "Invalid Connector")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      FlowBridge::WorkflowPublisher.publish!(
        workflow: workflow,
        graph: sample_graph(url: "mock://crm/contacts")
      )
    end

    assert_match(/url must use http or https/, error.message)
  end

  test "rejects invalid filter and retry policy config" do
    organization, = create_organization_with_key
    workflow = organization.workflows.create!(name: "Invalid Filter")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      FlowBridge::WorkflowPublisher.publish!(
        workflow: workflow,
        graph: {
          "nodes" => [
            { "key" => "incoming_webhook", "type" => "webhook_trigger", "config" => {} },
            { "key" => "gate", "type" => "filter", "config" => {} }
          ]
        },
        retry_policy: { max_attempts: 99 }
      )
    end

    assert_match(/filter node/, error.message)
    assert_match(/max_attempts/, error.message)
  end
end
