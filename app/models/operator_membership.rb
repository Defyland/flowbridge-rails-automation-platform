class OperatorMembership < ApplicationRecord
  ROLES = %w[owner operator viewer].freeze

  belongs_to :organization
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :organization_id }

  def allows?(permission)
    ApiKey::ROLE_PERMISSIONS.fetch(role).include?(permission.to_sym)
  end
end
