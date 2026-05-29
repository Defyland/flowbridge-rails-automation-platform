class NodeExecution < ApplicationRecord
  STATUSES = %w[running succeeded failed skipped].freeze

  belongs_to :workflow_execution

  validates :node_key, :node_type, :started_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :attempt, numericality: { only_integer: true, greater_than: 0 }
  validates :node_key, uniqueness: { scope: [ :workflow_execution_id, :attempt ] }

  def complete!(output)
    update!(
      status: "succeeded",
      output_json: FlowBridge::SecretMasker.mask_hash(output),
      completed_at: Time.current,
      duration_ms: elapsed_ms
    )
  end

  def fail!(error)
    update!(
      status: "failed",
      error_json: error,
      completed_at: Time.current,
      duration_ms: elapsed_ms
    )
  end

  def to_public_hash
    {
      id: id,
      node_key: node_key,
      node_type: node_type,
      status: status,
      attempt: attempt,
      input: input_json,
      output: output_json.presence,
      error: error_json.presence,
      duration_ms: duration_ms,
      started_at: started_at.iso8601,
      completed_at: completed_at&.iso8601
    }
  end

  private

  def elapsed_ms
    ((Time.current - started_at) * 1000).round
  end
end
