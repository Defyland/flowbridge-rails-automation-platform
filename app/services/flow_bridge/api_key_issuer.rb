module FlowBridge
  class ApiKeyIssuer
    IssuedKey = Struct.new(:api_key, :token, keyword_init: true)

    def self.issue!(organization:, name:, role: "owner", scopes: [])
      token = "fbk_#{SecureRandom.urlsafe_base64(32)}"
      api_key = organization.api_keys.create!(
        name: name,
        role: role,
        scopes_json: scopes,
        token_digest: TokenHasher.digest(token),
        token_hint: "#{token.first(8)}...#{token.last(4)}"
      )

      IssuedKey.new(api_key: api_key, token: token)
    end
  end
end
