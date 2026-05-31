require "socket"

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

  def sample_graph(url: "https://example.com/crm/contacts", extra_nodes: [])
    {
      "nodes" => [
        { "key" => "incoming_webhook", "type" => "webhook_trigger", "config" => {} },
        { "key" => "normalize", "type" => "transform", "config" => { "mapping" => { "email" => "$.email" } } },
        { "key" => "sync_crm", "type" => "http_request", "config" => { "method" => "POST", "url" => url, "timeout_seconds" => 2 } }
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

  def with_test_http_endpoint(status: 202, body: { accepted: true }, delay: 0)
    server = TCPServer.new("127.0.0.1", 0)
    requests = []
    mutex = Mutex.new
    thread = Thread.new do
      loop do
        client = server.accept
        raw_headers = +""

        while (line = client.gets)
          raw_headers << line
          break if line == "\r\n"
        end

        content_length = raw_headers[/content-length:\s*(\d+)/i, 1].to_i
        request_body = content_length.positive? ? client.read(content_length).to_s : ""
        mutex.synchronize { requests << { headers: raw_headers, body: request_body } }
        sleep delay if delay.positive?

        response_body = body.is_a?(String) ? body : JSON.generate(body)
        client.write([
          "HTTP/1.1 #{status} OK",
          "Content-Type: application/json",
          "Content-Length: #{response_body.bytesize}",
          "Connection: close",
          "",
          response_body
        ].join("\r\n"))
      ensure
        client&.close
      end
    rescue IOError, Errno::EBADF
      nil
    end

    yield "http://127.0.0.1:#{server.addr[1]}/contacts", requests
  ensure
    server&.close
    thread&.kill
    thread&.join
  end

  def with_env(overrides)
    previous = {}
    overrides.each do |key, value|
      previous[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
