class Workflow < ApplicationRecord
  STATUSES = %w[draft active archived].freeze

  belongs_to :organization
  has_many :workflow_versions, dependent: :restrict_with_exception
  has_many :workflow_executions, dependent: :restrict_with_exception

  before_validation :assign_slug, if: -> { slug.blank? && name.present? }

  validates :name, presence: true, length: { maximum: 120 }
  validates :slug, presence: true, uniqueness: { scope: :organization_id }, format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
  validates :status, inclusion: { in: STATUSES }

  def active_version
    workflow_versions.order(version_number: :desc).first
  end

  def to_public_hash(include_versions: false)
    payload = {
      id: id,
      organization_id: organization_id,
      name: name,
      slug: slug,
      status: status,
      description: description,
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
    payload[:versions] = workflow_versions.order(version_number: :desc).map(&:to_public_hash) if include_versions
    payload
  end

  private

  def assign_slug
    self.slug = name.parameterize
  end
end
