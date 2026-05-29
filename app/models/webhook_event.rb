class WebhookEvent < ApplicationRecord
  STATUSES = %w[accepted duplicate rejected].freeze

  belongs_to :organization
  belongs_to :workflow_version
  has_one :workflow_execution, dependent: :restrict_with_exception

  validates :idempotency_key, presence: true, uniqueness: { scope: :workflow_version_id }
  validates :status, inclusion: { in: STATUSES }
  validates :correlation_id, presence: true
  validates :received_at, presence: true

  def duplicate?
    status == "duplicate"
  end

  def to_public_hash
    {
      id: id,
      workflow_version_id: workflow_version_id,
      idempotency_key: idempotency_key,
      source_event_id: source_event_id,
      status: status,
      correlation_id: correlation_id,
      received_at: received_at.iso8601,
      execution_id: workflow_execution&.id
    }
  end
end
