module FlowBridge
  class CredentialCipher
    PURPOSE = "flowbridge-credentials-v1".freeze

    def self.encrypt(value)
      encryptor.encrypt_and_sign(value.to_s, purpose: PURPOSE)
    end

    def self.decrypt(ciphertext)
      return if ciphertext.blank?

      encryptor.decrypt_and_verify(ciphertext, purpose: PURPOSE)
    end

    def self.encryptor
      secret = ENV["FLOWBRIDGE_ENCRYPTION_KEY"].presence || Rails.application.secret_key_base
      key = ActiveSupport::KeyGenerator.new(secret).generate_key("flowbridge credential cipher", 32)
      ActiveSupport::MessageEncryptor.new(key)
    end
  end
end
