class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :operator_memberships, dependent: :destroy
  has_many :organizations, through: :operator_memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  def membership_for(organization)
    operator_memberships.find_by(organization: organization)
  end
end
