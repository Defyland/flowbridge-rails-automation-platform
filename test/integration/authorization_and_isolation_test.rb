require "test_helper"

class AuthorizationAndIsolationTest < ActionDispatch::IntegrationTest
  test "viewer API keys cannot mutate workflows" do
    organization, = create_organization_with_key
    viewer = FlowBridge::ApiKeyIssuer.issue!(organization: organization, name: "viewer", role: "viewer")

    post "/api/v1/workflows",
      params: { workflow: { name: "Not Allowed" } },
      headers: auth_headers(viewer.token),
      as: :json

    assert_response :forbidden
    assert_equal "forbidden", json_response.dig("error", "code")
  end

  test "API keys cannot access another tenant's workflow" do
    first_org, = create_organization_with_key(name: "First Tenant")
    second_org, _second_key, second_token = create_organization_with_key(name: "Second Tenant")
    workflow = first_org.workflows.create!(name: "Private Workflow")

    get "/api/v1/workflows/#{workflow.id}",
      headers: auth_headers(second_token),
      as: :json

    assert_response :not_found
    assert_equal second_org, ApiKey.authenticate(second_token).organization
  end
end
