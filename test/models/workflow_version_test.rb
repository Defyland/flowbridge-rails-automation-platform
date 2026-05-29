require "test_helper"

class WorkflowVersionTest < ActiveSupport::TestCase
  test "published versions are immutable execution artifacts" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)

    assert_no_changes -> { version.reload.graph_checksum } do
      assert_not version.update(graph_json: sample_graph(url: "mock://other"))
    end
    assert_includes version.errors[:base], "workflow versions are immutable"
  end

  test "requires a webhook trigger node" do
    organization, = create_organization_with_key
    workflow = organization.workflows.create!(name: "Missing Trigger")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      FlowBridge::WorkflowPublisher.publish!(
        workflow: workflow,
        graph: { "nodes" => [ { "key" => "sync", "type" => "http_request", "config" => { "url" => "mock://ok" } } ] }
      )
    end

    assert_match(/webhook_trigger/, error.message)
  end
end
