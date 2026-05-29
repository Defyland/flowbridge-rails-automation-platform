class Credential < ApplicationRecord
  KINDS = %w[api_key bearer_token basic_auth webhook_secret].freeze

  belongs_to :organization

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :kind, inclusion: { in: KINDS }
  validates :secret_ciphertext, presence: true

  def secret
    update_column(:last_used_at, Time.current)
    decrypted_secret
  end

  def decrypted_secret
    FlowBridge::CredentialCipher.decrypt(secret_ciphertext)
  end

  def secret=(plain_secret)
    self.secret_ciphertext = FlowBridge::CredentialCipher.encrypt(plain_secret)
  end

  def masked_secret
    FlowBridge::SecretMasker.mask(decrypted_secret)
  end

  def to_public_hash
    {
      id: id,
      name: name,
      kind: kind,
      masked_secret: masked_secret,
      metadata: metadata_json,
      last_used_at: last_used_at&.iso8601,
      created_at: created_at.iso8601
    }
  end
end
