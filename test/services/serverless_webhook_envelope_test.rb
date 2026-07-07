require "test_helper"

class ServerlessWebhookEnvelopeTest < ActiveSupport::TestCase
  test "normalizes serverless ingress fields into webhook ingestor metadata" do
    envelope = FlowBridge::ServerlessWebhookEnvelope.new(
      "schema_version" => 1,
      "source" => "stripe",
      "external_event_id" => "evt_123",
      "received_at" => "2026-07-07T15:10:00Z",
      "raw_body_sha256" => OpenSSL::Digest::SHA256.hexdigest("payload"),
      "correlation_id" => "corr-edge-1",
      "headers" => { "Stripe-Signature" => "t=1,v1=abc" },
      "payload" => { "id" => "evt_123" }
    )

    assert_equal "serverless/stripe/evt_123", envelope.idempotency_key
    assert_equal "stripe:evt_123", envelope.source_event_id
    assert_equal "t=1,v1=abc", envelope.flowbridge_headers.fetch("stripe-signature")
    assert_equal "serverless", envelope.flowbridge_headers.fetch("x-flowbridge-ingress")
  end

  test "rejects invalid schemas before reaching workflow ingestion" do
    error = assert_raises(FlowBridge::ServerlessWebhookEnvelope::InvalidEnvelope) do
      FlowBridge::ServerlessWebhookEnvelope.new(
        "schema_version" => 2,
        "source" => "stripe",
        "external_event_id" => "evt_123",
        "received_at" => "2026-07-07T15:10:00Z",
        "raw_body_sha256" => OpenSSL::Digest::SHA256.hexdigest("payload"),
        "payload" => { "id" => "evt_123" }
      )
    end

    assert_equal "schema_version must be 1", error.message
  end
end
