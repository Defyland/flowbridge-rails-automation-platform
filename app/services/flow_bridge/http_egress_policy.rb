require "ipaddr"
require "resolv"

module FlowBridge
  class HttpEgressPolicy
    class Violation < StandardError
      attr_reader :details

      def initialize(message, details: {})
        super(message)
        @details = details
      end
    end

    Result = Data.define(:host, :addresses, :connect_ip)

    BLOCKED_NETWORKS = [
      IPAddr.new("0.0.0.0/8"),
      IPAddr.new("10.0.0.0/8"),
      IPAddr.new("100.64.0.0/10"),
      IPAddr.new("127.0.0.0/8"),
      IPAddr.new("169.254.0.0/16"),
      IPAddr.new("172.16.0.0/12"),
      IPAddr.new("192.0.0.0/24"),
      IPAddr.new("192.0.2.0/24"),
      IPAddr.new("192.168.0.0/16"),
      IPAddr.new("198.18.0.0/15"),
      IPAddr.new("198.51.100.0/24"),
      IPAddr.new("203.0.113.0/24"),
      IPAddr.new("224.0.0.0/4"),
      IPAddr.new("240.0.0.0/4"),
      IPAddr.new("::/128"),
      IPAddr.new("::1/128"),
      IPAddr.new("64:ff9b::/96"),
      IPAddr.new("100::/64"),
      IPAddr.new("2001:db8::/32"),
      IPAddr.new("fc00::/7"),
      IPAddr.new("fe80::/10"),
      IPAddr.new("ff00::/8")
    ].freeze

    def self.check!(uri)
      new(uri).check!
    end

    def self.blocked_ip_literal?(host)
      ip = parse_ip(host)
      ip && blocked_ip?(ip) && !private_host_allowed?(host)
    end

    def self.private_host_allowed?(host)
      host_patterns("FLOWBRIDGE_CONNECTOR_PRIVATE_HOST_ALLOWLIST").any? { |pattern| host_matches?(host, pattern) }
    end

    def self.blocked_ip?(ip)
      BLOCKED_NETWORKS.any? { |network| network.include?(ip) }
    end

    def self.parse_ip(host)
      IPAddr.new(host.to_s)
    rescue IPAddr::InvalidAddressError
      nil
    end

    def self.host_patterns(env_name)
      ENV.fetch(env_name, "").split(",").map { |host| host.strip.downcase }.reject(&:blank?)
    end

    def self.host_matches?(host, pattern)
      normalized_host = host.to_s.downcase
      normalized_host == pattern || (pattern.start_with?(".") && normalized_host.end_with?(pattern))
    end

    def initialize(uri)
      @uri = uri
      @host = uri.host.to_s.downcase
    end

    def check!
      enforce_allowed_hosts!
      addresses = resolve_addresses
      enforce_blocked_networks!(addresses)

      Result.new(host: host, addresses: addresses, connect_ip: addresses.first)
    end

    private

    attr_reader :uri, :host

    def enforce_allowed_hosts!
      allowed_hosts = self.class.host_patterns("FLOWBRIDGE_CONNECTOR_ALLOWED_HOSTS")
      return if allowed_hosts.empty?
      return if allowed_hosts.any? { |pattern| self.class.host_matches?(host, pattern) }

      raise Violation.new(
        "HTTP connector host is not in the allowed host list",
        details: { host: host, allowed_hosts: allowed_hosts }
      )
    end

    def resolve_addresses
      literal_ip = self.class.parse_ip(host)
      return [ literal_ip.to_s ] if literal_ip

      addresses = Resolv.getaddresses(host).map { |address| self.class.parse_ip(address)&.to_s }.compact.uniq
      return addresses if addresses.any?

      raise Violation.new("HTTP connector host did not resolve", details: { host: host })
    rescue Resolv::ResolvError => error
      raise Violation.new(error.message, details: { host: host })
    end

    def enforce_blocked_networks!(addresses)
      return if self.class.private_host_allowed?(host)

      blocked_addresses = addresses.select { |address| self.class.blocked_ip?(IPAddr.new(address)) }
      return if blocked_addresses.empty?

      raise Violation.new(
        "HTTP connector target resolves to a blocked network",
        details: { host: host, blocked_addresses: blocked_addresses }
      )
    end
  end
end
