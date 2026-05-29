class Current < ActiveSupport::CurrentAttributes
  attribute :api_key, :organization, :request_id, :correlation_id, :session, :user
end
