require "test_helper"

class SecretMaskerTest < ActiveSupport::TestCase
  test "masks signatures and nested sensitive values by key" do
    payload = {
      "x-flowbridge-signature" => "sha256=very-sensitive-signature",
      "headers" => {
        "Authorization" => "Bearer very-sensitive-token",
        "X-Trace-Id" => "trace-1"
      }
    }

    masked = FlowBridge::SecretMasker.mask_hash(payload)

    assert_equal "sha2...ture", masked.fetch("x-flowbridge-signature")
    assert_equal "Bear...oken", masked.dig("headers", "Authorization")
    assert_equal "trace-1", masked.dig("headers", "X-Trace-Id")
  end

  test "masks sensitive URL query parameters while preserving non-sensitive context" do
    url = "https://api.example.test/contacts?access_token=very-sensitive-token&region=us"

    masked = FlowBridge::SecretMasker.mask_url(url)

    assert_equal "https://api.example.test/contacts?access_token=very...oken&region=us", masked
    refute_includes masked, "very-sensitive-token"
  end
end
