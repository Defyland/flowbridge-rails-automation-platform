module FlowBridge
  class RateLimiter
    Result = Data.define(:bucket, :count, :limit) do
      def exceeded?
        count > limit
      end
    end

    FALLBACK_MUTEX = Mutex.new

    def self.increment(bucket:, limit:, expires_in:)
      count = atomic_increment(bucket, expires_in: expires_in)
      Result.new(bucket: bucket, count: count, limit: limit.to_i)
    end

    def self.atomic_increment(bucket, expires_in:)
      Rails.cache.write(bucket, 0, expires_in: expires_in, unless_exist: true)
      Rails.cache.increment(bucket, 1, expires_in: expires_in) || fallback_increment(bucket, expires_in: expires_in)
    rescue NotImplementedError, NoMethodError
      fallback_increment(bucket, expires_in: expires_in)
    end
    private_class_method :atomic_increment

    def self.fallback_increment(bucket, expires_in:)
      FALLBACK_MUTEX.synchronize do
        count = Rails.cache.read(bucket).to_i + 1
        Rails.cache.write(bucket, count, expires_in: expires_in)
        count
      end
    end
    private_class_method :fallback_increment
  end
end
