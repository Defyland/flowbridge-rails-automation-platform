class WorkflowExecution < ApplicationRecord
  STATUSES = %w[queued running retrying succeeded failed canceled].freeze

  belongs_to :organization
  belongs_to :workflow
  belongs_to :workflow_version
  belongs_to :webhook_event, optional: true
  has_many :node_executions, dependent: :destroy
  has_many :dead_letters, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }
  validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :correlation_id, presence: true
  validates :idempotency_key, presence: true, uniqueness: { scope: :workflow_version_id }

  def terminal?
    %w[succeeded failed canceled].include?(status)
  end

  def duration_ms
    return unless started_at && completed_at

    ((completed_at - started_at) * 1000).round
  end

  def to_public_hash(include_nodes: false)
    payload = {
      id: id,
      workflow_id: workflow_id,
      workflow_version_id: workflow_version_id,
      webhook_event_id: webhook_event_id,
      status: status,
      attempt_count: attempt_count,
      idempotency_key: idempotency_key,
      correlation_id: correlation_id,
      error: error_json.presence,
      started_at: started_at&.iso8601,
      completed_at: completed_at&.iso8601,
      duration_ms: duration_ms,
      created_at: created_at.iso8601
    }
    payload[:nodes] = node_executions.order(:created_at, :id).map(&:to_public_hash) if include_nodes
    payload
  end
end
