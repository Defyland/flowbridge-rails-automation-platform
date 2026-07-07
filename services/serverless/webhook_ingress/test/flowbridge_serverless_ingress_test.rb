require "minitest/autorun"
require_relative "../lib/flowbridge_serverless_ingress"

class FlowbridgeServerlessIngressTest < Minitest::Test
  def test_normalizes_and_relays_api_gateway_events_to_rails_ingress
    client = FakeHttpClient.new(status: 202, body: '{"accepted":true}')
    raw_body = JSON.generate("id" => "evt_edge_1", "email" => "buyer@example.com")

    response = FlowBridgeServerlessIngress.handle(
      event: api_gateway_event(body: raw_body),
      env: env,
      http_client: client,
      clock: FixedClock
    )

    assert_equal 202, response.fetch("statusCode")
    assert_equal({ "accepted" => true, "correlation_id" => "api-gw-request-1" }, JSON.parse(response.fetch("body")))

    assert_equal 1, client.requests.size
    request = client.requests.first
    assert_equal "/api/v1/serverless/webhooks/customer.created", request.fetch(:uri).path
    assert_equal "application/json", request.fetch(:headers).fetch("Content-Type")

    envelope = JSON.parse(request.fetch(:body))
    assert_equal 1, envelope.fetch("schema_version")
    assert_equal "stripe", envelope.fetch("source")
    assert_equal "evt_edge_1", envelope.fetch("external_event_id")
    assert_equal "2026-07-07T15:30:00Z", envelope.fetch("received_at")
    assert_equal OpenSSL::Digest::SHA256.hexdigest(raw_body), envelope.fetch("raw_body_sha256")
    assert_equal({ "id" => "evt_edge_1", "email" => "buyer@example.com" }, envelope.fetch("payload"))
    assert_equal "t=1,v1=provider-signature", envelope.dig("headers", "stripe-signature")
    refute envelope.fetch("headers").key?("authorization")

    assert_equal FlowBridgeServerlessIngress.signature(
      secret: "serverless-secret",
      payload: request.fetch(:body)
    ), request.fetch(:headers).fetch("X-FlowBridge-Serverless-Signature")
  end

  def test_rejects_invalid_provider_json_without_relaying
    client = FakeHttpClient.new(status: 202, body: "{}")

    response = FlowBridgeServerlessIngress.handle(
      event: api_gateway_event(body: "{bad-json"),
      env: env,
      http_client: client,
      clock: FixedClock
    )

    assert_equal 400, response.fetch("statusCode")
    assert_equal "invalid_webhook", JSON.parse(response.fetch("body")).dig("error", "code")
    assert_empty client.requests
  end

  def test_returns_provider_safe_error_when_rails_relay_fails
    client = FakeHttpClient.new(status: 503, body: '{"error":"internal"}')

    response = FlowBridgeServerlessIngress.handle(
      event: api_gateway_event(body: JSON.generate("id" => "evt_edge_2")),
      env: env,
      http_client: client,
      clock: FixedClock
    )

    assert_equal 502, response.fetch("statusCode")
    body = JSON.parse(response.fetch("body"))
    assert_equal false, body.fetch("accepted")
    assert_equal "rails_ingress_unavailable", body.dig("error", "code")
    refute_includes response.fetch("body"), "internal"
  end

  private

  def env
    {
      "FLOWBRIDGE_SOURCE" => "stripe",
      "FLOWBRIDGE_RAILS_INGRESS_URL" => "https://flowbridge.example",
      "FLOWBRIDGE_SERVERLESS_INGRESS_SECRET" => "serverless-secret"
    }
  end

  def api_gateway_event(body:)
    {
      "body" => body,
      "isBase64Encoded" => false,
      "headers" => {
        "Stripe-Signature" => "t=1,v1=provider-signature",
        "Authorization" => "Bearer should-not-forward"
      },
      "pathParameters" => { "trigger_key" => "customer.created" },
      "requestContext" => { "requestId" => "api-gw-request-1" }
    }
  end

  class FixedClock
    def self.now
      Time.utc(2026, 7, 7, 15, 30, 0)
    end
  end

  class FakeHttpClient
    Response = Struct.new(:code, :body)

    attr_reader :requests

    def initialize(status:, body:)
      @status = status
      @body = body
      @requests = []
    end

    def post(uri:, body:, headers:, open_timeout:, read_timeout:)
      requests << {
        uri: uri,
        body: body,
        headers: headers,
        open_timeout: open_timeout,
        read_timeout: read_timeout
      }
      Response.new(@status, @body)
    end
  end
end
