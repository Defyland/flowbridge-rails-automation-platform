require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  test "assigns a stable slug and authenticates issued API keys by digest" do
    organization, api_key, token = create_organization_with_key(name: "North Star Ops")

    assert_equal "north-star-ops", organization.slug
    assert_equal api_key, ApiKey.authenticate(token)
    assert_nil ApiKey.authenticate("fbk_invalid")
  end

  test "enforces positive rate limit at the database boundary" do
    organization = Organization.new(name: "Bad Limit", rate_limit_per_minute: 0)

    assert_not organization.valid?
    assert_includes organization.errors[:rate_limit_per_minute], "must be greater than 0"
  end
end
