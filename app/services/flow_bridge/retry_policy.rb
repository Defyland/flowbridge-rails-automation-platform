module FlowBridge
  class RetryPolicy
    def self.exhausted?(attempt:, policy:)
      attempt >= policy.fetch("max_attempts", 3).to_i
    end

    def self.delay(attempt:, policy:)
      return 0.seconds if ENV["FLOWBRIDGE_DISABLE_RETRY_DELAY"] == "true"

      base = policy.fetch("base_delay_seconds", 30).to_i
      jitter = policy.fetch("jitter_seconds", 10).to_i
      (base * (2**[ attempt - 1, 0 ].max) + rand(0..jitter)).seconds
    end
  end
end
