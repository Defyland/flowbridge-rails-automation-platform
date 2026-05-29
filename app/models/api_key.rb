class ApiKey < ApplicationRecord
  ROLES = %w[owner operator viewer].freeze
  ROLE_PERMISSIONS = {
    "owner" => %i[
      organization.read workflows.read workflows.write credentials.read credentials.write
      executions.read executions.retry dead_letters.read dead_letters.manage
    ],
    "operator" => %i[
      organization.read workflows.read credentials.read executions.read executions.retry
      dead_letters.read dead_letters.manage
    ],
    "viewer" => %i[organization.read workflows.read executions.read dead_letters.read]
  }.freeze

  belongs_to :organization
  has_many :audit_logs, dependent: :nullify

  scope :active, -> { where(revoked_at: nil) }

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validates :token_hint, presence: true
  validates :role, inclusion: { in: ROLES }

  def self.authenticate(token)
    return if token.blank?

    active.includes(:organization).find_by(token_digest: FlowBridge::TokenHasher.digest(token))
  end

  def allows?(permission)
    ROLE_PERMISSIONS.fetch(role).include?(permission.to_sym)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def mark_used!
    update_column(:last_used_at, Time.current)
  end

  def to_public_hash
    {
      id: id,
      name: name,
      role: role,
      token_hint: token_hint,
      last_used_at: last_used_at&.iso8601,
      revoked_at: revoked_at&.iso8601,
      created_at: created_at.iso8601
    }
  end
end
