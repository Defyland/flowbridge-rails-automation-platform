require "test_helper"

class ServerlessWebhookIngressTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "ingests a signed serverless envelope through the normal webhook pipeline" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)
    raw_source_body = JSON.generate({ id: "evt-serverless-1", email: "edge@example.com" })
    raw_envelope = serverless_envelope_json(raw_source_body: raw_source_body)

    with_env("FLOWBRIDGE_SERVERLESS_INGRESS_SECRET" => "edge-secret") do
      assert_enqueued_with(job: WorkflowExecutionJob) do
        post "/api/v1/serverless/webhooks/#{version.trigger_key}",
          params: raw_envelope,
          headers: serverless_headers(raw_envelope)
      end
    end

    assert_response :accepted
    assert_equal false, json_response.fetch("duplicate")
    assert_equal "serverless/stripe/evt-serverless-1", json_response.dig("serverless_ingestion", "idempotency_key")
    assert_equal "corr-edge-1", json_response.dig("serverless_ingestion", "correlation_id")

    event = version.webhook_events.sole
    assert_equal "stripe:evt-serverless-1", event.source_event_id
    assert_equal({ "id" => "evt-serverless-1", "email" => "edge@example.com" }, event.payload_json)
    assert_equal "serverless", event.headers_json.fetch("x-flowbridge-ingress")
    assert_match(/\At=1,.\.\..+\z/, event.headers_json.fetch("stripe-signature"))
  end

  test "deduplicates serverless envelopes by source and external event id" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)
    raw_envelope = serverless_envelope_json(raw_source_body: JSON.generate({ id: "evt-duplicate" }))

    with_env("FLOWBRIDGE_SERVERLESS_INGRESS_SECRET" => "edge-secret") do
      post "/api/v1/serverless/webhooks/#{version.trigger_key}",
        params: raw_envelope,
        headers: serverless_headers(raw_envelope)
      assert_response :accepted

      post "/api/v1/serverless/webhooks/#{version.trigger_key}",
        params: raw_envelope,
        headers: serverless_headers(raw_envelope)
    end

    assert_response :accepted
    assert_equal true, json_response.fetch("duplicate")
    assert_equal 1, version.webhook_events.count
    assert_equal 1, version.workflow_executions.count
  end

  test "rejects unsigned serverless envelopes" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)
    raw_envelope = serverless_envelope_json(raw_source_body: JSON.generate({ id: "evt-invalid" }))

    with_env("FLOWBRIDGE_SERVERLESS_INGRESS_SECRET" => "edge-secret") do
      post "/api/v1/serverless/webhooks/#{version.trigger_key}",
        params: raw_envelope,
        headers: { "Content-Type" => "application/json", "X-FlowBridge-Serverless-Signature" => "sha256=bad" }
    end

    assert_response :unauthorized
    assert_equal "invalid_serverless_signature", json_response.dig("error", "code")
    assert_equal 0, version.webhook_events.count
  end

  test "rejects malformed serverless envelopes" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)
    raw_envelope = JSON.generate("not-an-object")

    with_env("FLOWBRIDGE_SERVERLESS_INGRESS_SECRET" => "edge-secret") do
      post "/api/v1/serverless/webhooks/#{version.trigger_key}",
        params: raw_envelope,
        headers: serverless_headers(raw_envelope)
    end

    assert_response :bad_request
    assert_equal "invalid_serverless_envelope", json_response.dig("error", "code")
    assert_equal 0, version.webhook_events.count
  end

  private

  def serverless_envelope_json(raw_source_body:)
    payload = JSON.parse(raw_source_body)

    JSON.generate(
      schema_version: 1,
      source: "stripe",
      external_event_id: payload.fetch("id"),
      received_at: "2026-07-07T15:10:00Z",
      raw_body_sha256: OpenSSL::Digest::SHA256.hexdigest(raw_source_body),
      correlation_id: "corr-edge-1",
      headers: { "Stripe-Signature" => "t=1,v1=abc123456789" },
      payload: payload
    )
  end

  def serverless_headers(raw_envelope)
    {
      "Content-Type" => "application/json",
      "X-FlowBridge-Serverless-Signature" => FlowBridge::SignatureVerifier.signature(
        secret: "edge-secret",
        payload: raw_envelope
      ),
      "X-Correlation-Id" => "corr-edge-1"
    }
  end
end
