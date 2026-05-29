class DeadLetter < ApplicationRecord
  STATUSES = %w[open retried resolved].freeze

  belongs_to :organization
  belongs_to :workflow_execution
  belongs_to :node_execution, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :reason, presence: true
  validates :retry_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def resolve!
    update!(status: "resolved", resolved_at: Time.current)
  end

  def mark_retried!
    update!(status: "retried", retry_count: retry_count + 1)
  end

  def to_public_hash
    {
      id: id,
      workflow_execution_id: workflow_execution_id,
      node_execution_id: node_execution_id,
      status: status,
      reason: reason,
      retry_count: retry_count,
      payload: payload_json,
      resolved_at: resolved_at&.iso8601,
      created_at: created_at.iso8601
    }
  end
end
