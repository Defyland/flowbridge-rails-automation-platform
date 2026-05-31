class WorkflowVersion < ApplicationRecord
  belongs_to :organization
  belongs_to :workflow
  has_many :webhook_events, dependent: :restrict_with_exception
  has_many :workflow_executions, dependent: :restrict_with_exception

  before_validation :copy_organization
  before_validation :assign_defaults, on: :create
  before_update :prevent_mutation

  validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :workflow_id }
  validates :trigger_key, presence: true, uniqueness: true
  validates :webhook_secret_ciphertext, presence: true
  validates :graph_checksum, presence: true
  validate :graph_contract

  def nodes
    graph_json.fetch("nodes", [])
  end

  def webhook_secret
    FlowBridge::CredentialCipher.decrypt(webhook_secret_ciphertext)
  end

  def webhook_secret=(plain_secret)
    self.webhook_secret_ciphertext = FlowBridge::CredentialCipher.encrypt(plain_secret)
  end

  def retry_policy
    {
      "max_attempts" => 3,
      "base_delay_seconds" => 30,
      "jitter_seconds" => 10
    }.merge(retry_policy_json || {})
  end

  def to_public_hash(include_graph: false)
    payload = {
      id: id,
      workflow_id: workflow_id,
      version_number: version_number,
      trigger_key: trigger_key,
      graph_checksum: graph_checksum,
      retry_policy: retry_policy,
      published_at: published_at.iso8601,
      created_at: created_at.iso8601
    }
    payload[:graph] = graph_json if include_graph
    payload
  end

  private

  def copy_organization
    self.organization ||= workflow&.organization
  end

  def assign_defaults
    self.published_at ||= Time.current
    self.trigger_key ||= [
      workflow&.organization&.slug || "org",
      workflow&.slug || "workflow",
      "v#{version_number || 1}",
      SecureRandom.hex(4)
    ].join("-")
    self.webhook_secret = "whsec_#{SecureRandom.hex(24)}" if webhook_secret_ciphertext.blank?
    self.graph_checksum ||= FlowBridge::GraphChecksum.call(graph_json)
  end

  def prevent_mutation
    errors.add(:base, "workflow versions are immutable")
    throw :abort
  end

  def graph_contract
    FlowBridge::WorkflowGraphValidator.call(graph: graph_json, retry_policy: retry_policy_json).issues.each do |issue|
      errors.add(issue.attribute, issue.message)
    end
  end
end
