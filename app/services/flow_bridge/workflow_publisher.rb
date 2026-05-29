module FlowBridge
  class WorkflowPublisher
    PublishedVersion = Struct.new(:workflow_version, :webhook_secret, keyword_init: true)

    def self.publish!(workflow:, graph:, retry_policy: {}, actor: Current.api_key)
      graph = graph.deep_stringify_keys
      retry_policy = retry_policy.deep_stringify_keys

      workflow.with_lock do
        version_number = workflow.workflow_versions.maximum(:version_number).to_i + 1
        workflow_version = workflow.workflow_versions.create!(
          organization: workflow.organization,
          version_number: version_number,
          graph_json: graph,
          retry_policy_json: retry_policy
        )
        workflow.update!(status: "active")
        AuditLog.record!(
          organization: workflow.organization,
          api_key: actor,
          action: "workflow_version.published",
          subject: workflow_version,
          metadata: { workflow_id: workflow.id, version_number: version_number }
        )

        PublishedVersion.new(
          workflow_version: workflow_version,
          webhook_secret: workflow_version.webhook_secret
        )
      end
    end
  end
end
