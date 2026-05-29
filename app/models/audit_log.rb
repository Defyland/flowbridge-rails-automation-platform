class AuditLog < ApplicationRecord
  belongs_to :organization
  belongs_to :api_key, optional: true

  validates :action, :subject_type, :subject_id, presence: true

  def self.record!(organization:, action:, subject:, api_key: Current.api_key, metadata: {}, ip_address: nil)
    create!(
      organization: organization,
      api_key: api_key,
      action: action,
      subject_type: subject.class.name,
      subject_id: subject.id.to_s,
      correlation_id: Current.correlation_id,
      ip_address: ip_address,
      metadata_json: FlowBridge::SecretMasker.mask_hash(metadata)
    )
  end
end
