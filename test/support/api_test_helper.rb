module ApiTestHelper
  def json_response
    JSON.parse(response.body)
  end

  def create_organization_with_key(name: "Acme Ops", role: "owner", rate_limit_per_minute: 120)
    organization = Organization.create!(name: name, rate_limit_per_minute: rate_limit_per_minute)
    issued = FlowBridge::ApiKeyIssuer.issue!(organization: organization, name: "#{role} key", role: role)
    [ organization, issued.api_key, issued.token ]
  end

  def auth_headers(token, correlation_id: "test-correlation")
    {
      "Authorization" => "Bearer #{token}",
      "X-Correlation-Id" => correlation_id
    }
  end

  def sample_graph(url: "mock://crm/contacts", extra_nodes: [])
    {
      "nodes" => [
        { "key" => "incoming_webhook", "type" => "webhook_trigger", "config" => {} },
        { "key" => "normalize", "type" => "transform", "config" => { "mapping" => { "email" => "$.email" } } },
        { "key" => "sync_crm", "type" => "http_request", "config" => { "method" => "POST", "url" => url } }
      ] + extra_nodes
    }
  end

  def publish_workflow_version(organization:, graph: sample_graph, retry_policy: {})
    workflow = organization.workflows.create!(name: "Lead Sync")
    FlowBridge::WorkflowPublisher.publish!(
      workflow: workflow,
      graph: graph,
      retry_policy: retry_policy
    ).workflow_version
  end

  def webhook_headers_for(workflow_version, raw_payload, event_id: "evt-test-1")
    {
      "Content-Type" => "application/json",
      "X-FlowBridge-Event-Id" => event_id,
      "X-FlowBridge-Signature" => FlowBridge::SignatureVerifier.signature(
        secret: workflow_version.webhook_secret,
        payload: raw_payload
      ),
      "X-Correlation-Id" => "corr-#{event_id}"
    }
  end
end
