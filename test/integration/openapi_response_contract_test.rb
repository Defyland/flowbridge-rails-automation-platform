require "test_helper"
require "yaml"

class OpenapiResponseContractTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    Rails.cache.clear
  end

  test "documents successful API responses with schemas that match real JSON payloads" do
    post "/api/v1/organizations",
      params: { organization: { name: "Contract Verified #{SecureRandom.hex(4)}" } },
      as: :json
    assert_openapi_json_response("/api/v1/organizations", :post, :created)

    organization_id = json_response.dig("organization", "id")
    token = json_response.dig("api_key", "token")

    get "/api/v1/organizations/#{organization_id}", headers: auth_headers(token), as: :json
    assert_openapi_json_response("/api/v1/organizations/{id}", :get, :ok)

    post "/api/v1/credentials",
      params: {
        credential: {
          name: "CRM API #{SecureRandom.hex(3)}",
          kind: "api_key",
          secret: "sk_test_contract",
          metadata_json: { service: "crm" }
        }
      },
      headers: auth_headers(token),
      as: :json
    assert_openapi_json_response("/api/v1/credentials", :post, :created)

    credential_id = json_response.dig("credential", "id")

    get "/api/v1/credentials", headers: auth_headers(token), as: :json
    assert_openapi_json_response("/api/v1/credentials", :get, :ok)

    get "/api/v1/credentials/#{credential_id}", headers: auth_headers(token), as: :json
    assert_openapi_json_response("/api/v1/credentials/{id}", :get, :ok)

    post "/api/v1/workflows",
      params: { workflow: { name: "Lead Intake #{SecureRandom.hex(3)}", description: "Contract test workflow" } },
      headers: auth_headers(token),
      as: :json
    assert_openapi_json_response("/api/v1/workflows", :post, :created)

    workflow_id = json_response.dig("workflow", "id")

    get "/api/v1/workflows", headers: auth_headers(token), as: :json
    assert_openapi_json_response("/api/v1/workflows", :get, :ok)

    workflow_version_id = nil

    with_test_http_endpoint(status: 202, body: { accepted: true, upstream_id: "contract-crm-1" }) do |url, _requests|
      post "/api/v1/workflows/#{workflow_id}/versions",
        params: { workflow_version: { graph: sample_graph(url: url), retry_policy: { max_attempts: 2 } } },
        headers: auth_headers(token),
        as: :json
      assert_openapi_json_response("/api/v1/workflows/{workflow_id}/versions", :post, :created)

      workflow_version_id = json_response.dig("workflow_version", "id")
      trigger_key = json_response.dig("workflow_version", "trigger_key")
      webhook_secret = json_response.fetch("webhook_secret")

      get "/api/v1/workflows/#{workflow_id}", headers: auth_headers(token), as: :json
      assert_openapi_json_response("/api/v1/workflows/{id}", :get, :ok)

      get "/api/v1/workflows/#{workflow_id}/versions", headers: auth_headers(token), as: :json
      assert_openapi_json_response("/api/v1/workflows/{workflow_id}/versions", :get, :ok)

      get "/api/v1/workflows/#{workflow_id}/versions/#{workflow_version_id}",
        headers: auth_headers(token),
        as: :json
      assert_openapi_json_response("/api/v1/workflows/{workflow_id}/versions/{id}", :get, :ok)

      raw_payload = JSON.generate({ email: "contract@example.com", plan: "scale" })
      assert_enqueued_with(job: WorkflowExecutionJob) do
        post "/api/v1/webhooks/#{trigger_key}",
          params: raw_payload,
          headers: {
            "Content-Type" => "application/json",
            "X-FlowBridge-Event-Id" => "evt-contract-success",
            "X-FlowBridge-Signature" => FlowBridge::SignatureVerifier.signature(
              secret: webhook_secret,
              payload: raw_payload
            ),
            "X-Correlation-Id" => "corr-contract-success"
          }
      end
      assert_openapi_json_response("/api/v1/webhooks/{trigger_key}", :post, :accepted)

      execution_id = json_response.dig("workflow_execution", "id")

      raw_source_body = JSON.generate({ id: "evt-contract-serverless", email: "serverless-contract@example.com" })
      raw_envelope = JSON.generate(
        schema_version: 1,
        source: "stripe",
        external_event_id: "evt-contract-serverless",
        received_at: "2026-07-07T15:20:00Z",
        raw_body_sha256: OpenSSL::Digest::SHA256.hexdigest(raw_source_body),
        correlation_id: "corr-contract-serverless",
        headers: { "Stripe-Signature" => "t=1,v1=serverless123456" },
        payload: JSON.parse(raw_source_body)
      )

      with_env("FLOWBRIDGE_SERVERLESS_INGRESS_SECRET" => "contract-edge-secret") do
        assert_enqueued_with(job: WorkflowExecutionJob) do
          post "/api/v1/serverless/webhooks/#{trigger_key}",
            params: raw_envelope,
            headers: {
              "Content-Type" => "application/json",
              "X-FlowBridge-Serverless-Signature" => FlowBridge::SignatureVerifier.signature(
                secret: "contract-edge-secret",
                payload: raw_envelope
              ),
              "X-Correlation-Id" => "corr-contract-serverless"
            }
        end
      end
      assert_openapi_json_response("/api/v1/serverless/webhooks/{trigger_key}", :post, :accepted)

      perform_enqueued_jobs

      get "/api/v1/executions", headers: auth_headers(token), as: :json
      assert_openapi_json_response("/api/v1/executions", :get, :ok)

      get "/api/v1/executions/#{execution_id}", headers: auth_headers(token), as: :json
      assert_openapi_json_response("/api/v1/executions/{id}", :get, :ok)
    end

    workflow_version = WorkflowVersion.find(workflow_version_id)
    failed_execution = create_failed_execution(workflow_version, idempotency_key: "evt-contract-retry")

    post "/api/v1/executions/#{failed_execution.id}/retry", headers: auth_headers(token), as: :json
    assert_openapi_json_response("/api/v1/executions/{id}/retry", :post, :accepted)

    dead_letter_execution = create_failed_execution(workflow_version, idempotency_key: "evt-contract-dead-letter")
    dead_letter = workflow_version.organization.dead_letters.create!(
      workflow_execution: dead_letter_execution,
      reason: "contract_failure",
      payload_json: { idempotency_key: dead_letter_execution.idempotency_key }
    )

    get "/api/v1/dead_letters", headers: auth_headers(token), as: :json
    assert_openapi_json_response("/api/v1/dead_letters", :get, :ok)

    get "/api/v1/dead_letters/#{dead_letter.id}", headers: auth_headers(token), as: :json
    assert_openapi_json_response("/api/v1/dead_letters/{id}", :get, :ok)

    post "/api/v1/dead_letters/#{dead_letter.id}/retry", headers: auth_headers(token), as: :json
    assert_openapi_json_response("/api/v1/dead_letters/{id}/retry", :post, :accepted)

    resolvable_execution = create_failed_execution(workflow_version, idempotency_key: "evt-contract-resolve")
    resolvable_dead_letter = workflow_version.organization.dead_letters.create!(
      workflow_execution: resolvable_execution,
      reason: "contract_resolved",
      payload_json: { idempotency_key: resolvable_execution.idempotency_key }
    )

    post "/api/v1/dead_letters/#{resolvable_dead_letter.id}/resolve", headers: auth_headers(token), as: :json
    assert_openapi_json_response("/api/v1/dead_letters/{id}/resolve", :post, :ok)
  end

  test "documents standard API error responses" do
    get "/api/v1/workflows", as: :json

    assert_openapi_json_response("/api/v1/workflows", :get, :unauthorized)
    assert_equal "unauthorized", json_response.dig("error", "code")
  end

  private

  def assert_openapi_json_response(path, method, status)
    assert_response status
    schema = documented_json_response_schema(path, method, status)
    assert_schema_matches(schema, json_response, "$")
  end

  def documented_json_response_schema(path, method, status)
    response_spec = documented_response(path, method, status)
    response_spec.dig("content", "application/json", "schema") ||
      flunk("#{method.to_s.upcase} #{path} #{Rack::Utils.status_code(status)} must document an application/json schema")
  end

  def documented_response(path, method, status)
    operation = openapi_document.fetch("paths").fetch(path).fetch(method.to_s)
    response_spec = operation.fetch("responses").fetch(Rack::Utils.status_code(status).to_s)
    resolve_openapi_ref(response_spec)
  end

  def assert_schema_matches(schema, value, pointer)
    schema = resolve_openapi_ref(schema)

    schema.fetch("allOf", []).each do |subschema|
      assert_schema_matches(subschema, value, pointer)
    end

    if schema.key?("enum")
      assert_includes schema.fetch("enum"), value, "#{pointer} should be one of #{schema.fetch("enum").inspect}"
    end

    types = schema_types(schema)
    if value.nil?
      assert_includes types, "null", "#{pointer} should allow null"
      return
    end

    matching_type = types.find { |type| schema_type_matches?(type, value) }
    assert matching_type, "#{pointer} should match #{types.inspect}, got #{value.class}"

    case matching_type
    when "object"
      assert_object_schema(schema, value, pointer)
    when "array"
      value.each_with_index do |item, index|
        assert_schema_matches(schema.fetch("items"), item, "#{pointer}[#{index}]")
      end
    when "string"
      assert_date_time(value, pointer) if schema["format"] == "date-time"
    end
  end

  def assert_object_schema(schema, value, pointer)
    assert_kind_of Hash, value, "#{pointer} should be an object"

    required = schema.fetch("required", [])
    required.each do |property|
      assert value.key?(property), "#{pointer} should include required property #{property.inspect}"
    end

    properties = schema.fetch("properties", {})
    properties.each do |property, property_schema|
      next unless value.key?(property)

      assert_schema_matches(property_schema, value.fetch(property), "#{pointer}.#{property}")
    end

    additional_properties = schema.fetch("additionalProperties", true)
    undocumented_keys = value.keys - properties.keys

    if additional_properties == false
      assert_empty undocumented_keys, "#{pointer} has undocumented properties: #{undocumented_keys.inspect}"
    elsif additional_properties.is_a?(Hash)
      undocumented_keys.each do |property|
        assert_schema_matches(additional_properties, value.fetch(property), "#{pointer}.#{property}")
      end
    end
  end

  def assert_date_time(value, pointer)
    Time.iso8601(value)
  rescue ArgumentError
    flunk("#{pointer} should be an ISO 8601 date-time")
  end

  def schema_types(schema)
    types = Array(schema["type"]).compact
    types = [ "object" ] if types.empty? && schema.key?("properties")
    types = [ "array" ] if types.empty? && schema.key?("items")
    types
  end

  def schema_type_matches?(type, value)
    case type
    when "object"
      value.is_a?(Hash)
    when "array"
      value.is_a?(Array)
    when "integer"
      value.is_a?(Integer) && !value.is_a?(TrueClass) && !value.is_a?(FalseClass)
    when "number"
      value.is_a?(Numeric)
    when "string"
      value.is_a?(String)
    when "boolean"
      value == true || value == false
    else
      false
    end
  end

  def resolve_openapi_ref(spec)
    return spec unless spec.is_a?(Hash) && spec.key?("$ref")

    spec.fetch("$ref")
      .delete_prefix("#/")
      .split("/")
      .reduce(openapi_document) { |node, key| node.fetch(key) }
  end

  def create_failed_execution(workflow_version, idempotency_key:)
    workflow_version.workflow_executions.create!(
      organization: workflow_version.organization,
      workflow: workflow_version.workflow,
      status: "failed",
      attempt_count: 1,
      idempotency_key: idempotency_key,
      correlation_id: "corr-#{idempotency_key}",
      input_json: { contract: true },
      error_json: { code: "contract_failure" },
      started_at: 1.second.ago,
      completed_at: Time.current
    )
  end

  def openapi_document
    @openapi_document ||= YAML.load_file(Rails.root.join("openapi.yaml"))
  end
end
