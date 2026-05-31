require "test_helper"

class NodeExecutorTest < ActiveSupport::TestCase
  test "http_request node performs a real HTTP call and masks credential headers" do
    organization, = create_organization_with_key
    credential = organization.credentials.new(name: "CRM token", kind: "bearer_token")
    credential.secret = "super-secret-token-value"
    credential.save!

    with_test_http_endpoint(status: 201, body: { id: "contact_123" }) do |url, requests|
      connector_url = "#{url}?access_token=upstream-secret-token&region=us"
      result = FlowBridge::NodeExecutor.new(
        organization: organization,
        node: {
          "key" => "sync_crm",
          "type" => "http_request",
          "config" => {
            "method" => "POST",
            "url" => connector_url,
            "credential_id" => credential.id,
            "headers" => { "X-Trace-Id" => "trace-1" }
          }
        },
        input: {
          "execution" => { "id" => 42, "correlation_id" => "corr-node-test" },
          "event" => { "email" => "buyer@example.com" },
          "previous_outputs" => {}
        }
      ).call

      assert_equal 201, result.dig("response", "status")
      assert_equal({ "id" => "contact_123" }, result.dig("response", "body"))
      assert_includes requests.first.fetch(:headers), "Authorization: Bearer super-secret-token-value"
      assert_includes requests.first.fetch(:headers), "access_token=upstream-secret-token"
      assert_includes requests.first.fetch(:headers), "Idempotency-Key: flowbridge:execution:42:node:sync_crm"
      assert_match(/X-Flowbridge-Correlation-Id: corr-node-test/i, requests.first.fetch(:headers))
      assert_equal "Bear...alue", result.dig("request", "headers", "Authorization")
      assert_equal "#{url}?access_token=upst...oken&region=us", result.dig("request", "url")
      refute_includes result.to_s, "upstream-secret-token"
    end
  end

  test "http_request node classifies client errors as permanent failures" do
    organization, = create_organization_with_key

    with_test_http_endpoint(status: 422, body: { error: "invalid" }) do |url, _requests|
      connector_url = "#{url}?api_key=upstream-secret-token"
      error = assert_raises(FlowBridge::NodeExecutor::ExecutionError) do
        FlowBridge::NodeExecutor.new(
          organization: organization,
          node: {
            "key" => "sync_crm",
            "type" => "http_request",
            "config" => { "method" => "POST", "url" => connector_url }
          },
          input: { "event" => { "email" => "bad@example.com" }, "previous_outputs" => {} }
        ).call
      end

      assert_equal "http_permanent_failure", error.code
      assert_equal false, error.retriable?
      assert_equal 422, error.details.fetch(:status)
      assert_equal "#{url}?api_key=upst...oken", error.details.fetch(:url)
      refute_includes error.to_h.to_s, "upstream-secret-token"
    end
  end

  test "http_request node rejects blocked egress targets before network access" do
    organization, = create_organization_with_key

    error = assert_raises(FlowBridge::NodeExecutor::ExecutionError) do
      FlowBridge::NodeExecutor.new(
        organization: organization,
        node: {
          "key" => "sync_crm",
          "type" => "http_request",
          "config" => { "method" => "GET", "url" => "http://169.254.169.254/latest/meta-data" }
        },
        input: { "event" => {}, "previous_outputs" => {} }
      ).call
    end

    assert_equal "http_invalid_request", error.code
    assert_match(/blocked network/, error.message)
  end
end
