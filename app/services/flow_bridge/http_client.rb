require "base64"
require "json"
require "net/http"
require "uri"

module FlowBridge
  class HttpClient
    class Error < StandardError
      attr_reader :details

      def initialize(message, details: {})
        super(message)
        @details = details
      end
    end

    class InvalidRequestError < Error; end
    class ConnectionError < Error; end
    class TimeoutError < Error; end

    Result = Data.define(:status, :headers, :body, :duration_ms) do
      def success?
        status.between?(200, 299)
      end
    end

    RETRIABLE_STATUSES = [ 408, 409, 425, 429 ].freeze
    MAX_BODY_BYTES = 32.kilobytes

    def self.request(url:, method:, headers:, body:, timeout_seconds:)
      new(
        url: url,
        method: method,
        headers: headers,
        body: body,
        timeout_seconds: timeout_seconds
      ).request
    end

    def self.retriable_status?(status)
      RETRIABLE_STATUSES.include?(status.to_i) || status.to_i >= 500
    end

    def initialize(url:, method:, headers:, body:, timeout_seconds:)
      @uri = parse_uri(url)
      @egress = FlowBridge::HttpEgressPolicy.check!(uri)
      @method = method.to_s.upcase
      @headers = headers || {}
      @body = body
      @timeout_seconds = parse_timeout(timeout_seconds)
    rescue FlowBridge::HttpEgressPolicy::Violation => error
      raise InvalidRequestError.new(error.message, details: error.details)
    end

    def request
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = perform_request
      Result.new(
        status: response.code.to_i,
        headers: response.to_hash.transform_values { |values| values.join(", ") },
        body: parse_body(response),
        duration_ms: elapsed_ms(started_at)
      )
    rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error => error
      raise TimeoutError.new(error.message, details: { url: safe_url, method: method })
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError, SocketError, IOError => error
      raise ConnectionError.new(error.message, details: { url: safe_url, method: method })
    end

    private

    attr_reader :uri, :egress, :method, :headers, :body, :timeout_seconds

    def parse_uri(url)
      uri = URI.parse(url.to_s)
      return uri if (uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)) && uri.host.present?

      raise InvalidRequestError.new("HTTP connector URL must use http or https", details: { url: url })
    rescue URI::InvalidURIError => error
      raise InvalidRequestError.new(error.message, details: { url: url })
    end

    def parse_timeout(timeout)
      Integer(timeout).tap do |value|
        unless value.between?(1, 30)
          raise InvalidRequestError.new(
            "HTTP connector timeout_seconds must be between 1 and 30",
            details: { timeout_seconds: timeout }
          )
        end
      end
    rescue ArgumentError, TypeError
      raise InvalidRequestError.new(
        "HTTP connector timeout_seconds must be an integer",
        details: { timeout_seconds: timeout }
      )
    end

    def perform_request
      http = Net::HTTP.new(uri.host, uri.port)
      http.ipaddr = egress.connect_ip
      http_options.each { |key, value| http.public_send("#{key}=", value) }

      http.start do |connection|
        connection.request(build_request)
      end
    end

    def http_options
      {
        use_ssl: uri.scheme == "https",
        open_timeout: timeout_seconds,
        read_timeout: timeout_seconds
      }.tap do |options|
        options[:write_timeout] = timeout_seconds if Net::HTTP.method_defined?(:write_timeout=)
      end
    end

    def build_request
      request = request_class.new(uri)
      headers.each { |key, value| request[key.to_s] = value.to_s }

      unless method == "GET"
        request["Content-Type"] ||= "application/json"
        request.body = JSON.generate(body || {})
      end

      request
    end

    def request_class
      {
        "GET" => Net::HTTP::Get,
        "POST" => Net::HTTP::Post,
        "PUT" => Net::HTTP::Put,
        "PATCH" => Net::HTTP::Patch,
        "DELETE" => Net::HTTP::Delete
      }.fetch(method) do
        raise InvalidRequestError.new("unsupported HTTP method #{method}", details: { method: method })
      end
    end

    def parse_body(response)
      raw_body = response.body.to_s.byteslice(0, MAX_BODY_BYTES)
      return {} if raw_body.blank?

      if response["content-type"].to_s.include?("json")
        JSON.parse(raw_body)
      else
        raw_body
      end
    rescue JSON::ParserError
      raw_body
    end

    def elapsed_ms(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    end

    def safe_url
      uri.to_s
    end
  end
end
