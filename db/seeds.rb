organization = Organization.find_or_create_by!(slug: "demo-ops") do |org|
  org.name = "Demo Ops"
  org.plan = "launch"
  org.rate_limit_per_minute = 500
end

issued_key = if organization.api_keys.none?
  FlowBridge::ApiKeyIssuer.issue!(organization: organization, name: "Demo owner", role: "owner")
end

workflow = organization.workflows.find_or_create_by!(slug: "lead-intake") do |item|
  item.name = "Lead Intake"
  item.description = "Demo workflow that receives a webhook and syncs a lead to a mock CRM."
end

operator = User.find_or_create_by!(email_address: "operator@flowbridge.local") do |user|
  user.password = "password123"
  user.password_confirmation = "password123"
end

OperatorMembership.find_or_create_by!(organization: organization, user: operator) do |membership|
  membership.role = "owner"
end

if workflow.workflow_versions.none?
  FlowBridge::WorkflowPublisher.publish!(
    workflow: workflow,
    graph: {
      nodes: [
        { key: "incoming_webhook", type: "webhook_trigger", config: {} },
        { key: "normalize", type: "transform", config: { mapping: { email: "$.email" } } },
        { key: "sync_crm", type: "http_request", config: { method: "POST", url: "mock://crm/contacts" } }
      ]
    },
    retry_policy: { max_attempts: 3, base_delay_seconds: 30, jitter_seconds: 10 }
  )
end

puts "Seeded FlowBridge demo organization #{organization.slug}"
if Rails.env.development?
  puts "Demo operator: operator@flowbridge.local / password123"
  puts "Demo API key token: #{issued_key.token}" if issued_key
end
