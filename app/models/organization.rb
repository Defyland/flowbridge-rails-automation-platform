class Organization < ApplicationRecord
  PLANS = %w[launch scale enterprise].freeze

  has_many :api_keys, dependent: :destroy
  has_many :operator_memberships, dependent: :destroy
  has_many :users, through: :operator_memberships
  has_many :workflows, dependent: :destroy
  has_many :workflow_versions, dependent: :restrict_with_exception
  has_many :credentials, dependent: :destroy
  has_many :webhook_events, dependent: :restrict_with_exception
  has_many :workflow_executions, dependent: :restrict_with_exception
  has_many :dead_letters, dependent: :restrict_with_exception
  has_many :audit_logs, dependent: :destroy

  before_validation :assign_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true, length: { maximum: 120 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
  validates :plan, inclusion: { in: PLANS }
  validates :rate_limit_per_minute, numericality: { only_integer: true, greater_than: 0 }

  def to_public_hash
    {
      id: id,
      name: name,
      slug: slug,
      plan: plan,
      rate_limit_per_minute: rate_limit_per_minute,
      created_at: created_at.iso8601
    }
  end

  private

  def assign_slug
    self.slug = name.parameterize
  end
end
