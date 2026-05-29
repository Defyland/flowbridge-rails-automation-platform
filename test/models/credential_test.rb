require "test_helper"

class CredentialTest < ActiveSupport::TestCase
  test "stores encrypted credential material and exposes only masked values" do
    organization, = create_organization_with_key
    credential = organization.credentials.new(name: "crm-token", kind: "bearer_token")
    credential.secret = "super-secret-token-123"
    credential.save!

    assert_no_match "super-secret-token-123", credential.secret_ciphertext
    assert_equal "supe...-123", credential.masked_secret
    assert_equal "super-secret-token-123", credential.secret
    assert credential.reload.last_used_at
  end
end
