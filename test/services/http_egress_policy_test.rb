require "test_helper"

class HttpEgressPolicyTest < ActiveSupport::TestCase
  test "blocks metadata service and loopback targets by default" do
    metadata_error = assert_raises(FlowBridge::HttpEgressPolicy::Violation) do
      FlowBridge::HttpEgressPolicy.check!(URI.parse("http://169.254.169.254/latest/meta-data"))
    end
    assert_match(/blocked network/, metadata_error.message)

    loopback_error = assert_raises(FlowBridge::HttpEgressPolicy::Violation) do
      FlowBridge::HttpEgressPolicy.check!(URI.parse("http://127.0.0.1:3000/internal"))
    end
    assert_match(/blocked network/, loopback_error.message)
  end

  test "allows private connector hosts only when explicitly allowlisted" do
    with_env("FLOWBRIDGE_CONNECTOR_PRIVATE_HOST_ALLOWLIST" => "127.0.0.1") do
      result = FlowBridge::HttpEgressPolicy.check!(URI.parse("http://127.0.0.1:3000/internal"))

      assert_equal "127.0.0.1", result.host
      assert_equal [ "127.0.0.1" ], result.addresses
    end
  end

  test "enforces optional connector host allowlist" do
    with_env("FLOWBRIDGE_CONNECTOR_ALLOWED_HOSTS" => "api.allowed.example") do
      error = assert_raises(FlowBridge::HttpEgressPolicy::Violation) do
        FlowBridge::HttpEgressPolicy.check!(URI.parse("https://api.denied.example/contacts"))
      end

      assert_match(/allowed host list/, error.message)
    end
  end
end
