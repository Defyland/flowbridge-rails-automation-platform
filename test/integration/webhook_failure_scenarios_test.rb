require "test_helper"

class WebhookFailureScenariosTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "rejects invalid webhook signatures" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)

    post "/api/v1/webhooks/#{version.trigger_key}",
      params: JSON.generate({ email: "bad@example.com" }),
      headers: {
        "Content-Type" => "application/json",
        "X-FlowBridge-Event-Id" => "evt-invalid-signature",
        "X-FlowBridge-Signature" => "sha256=bad"
      }

    assert_response :unauthorized
    assert_equal "invalid_webhook_signature", json_response.dig("error", "code")
    assert_equal 0, version.webhook_events.count
  end

  test "deduplicates webhook events by workflow version and idempotency key" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)
    raw_payload = JSON.generate({ email: "same@example.com" })
    headers = webhook_headers_for(version, raw_payload, event_id: "evt-duplicate")

    post "/api/v1/webhooks/#{version.trigger_key}", params: raw_payload, headers: headers
    assert_response :accepted
    assert_equal false, json_response.fetch("duplicate")

    post "/api/v1/webhooks/#{version.trigger_key}", params: raw_payload, headers: headers
    assert_response :accepted
    assert_equal true, json_response.fetch("duplicate")
    assert_equal 1, version.webhook_events.count
    assert_equal 1, version.workflow_executions.count
  end

  test "persists webhook headers without storing the raw signature" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)
    raw_payload = JSON.generate({ email: "masked@example.com" })
    headers = webhook_headers_for(version, raw_payload, event_id: "evt-masked-signature")

    post "/api/v1/webhooks/#{version.trigger_key}", params: raw_payload, headers: headers

    assert_response :accepted
    event = version.webhook_events.sole
    assert_equal "evt-masked-signature", event.source_event_id
    refute_includes event.headers_json.to_s, headers.fetch("X-FlowBridge-Signature")
    assert_match(/\Asha2\.\.\..+\z/, event.headers_json.fetch("x-flowbridge-signature"))
  end
end
