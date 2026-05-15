# frozen_string_literal: true

require "json"
require "bigdecimal"

module SavvyOpenrouter
  # Persists OpenRouter HTTP exchanges when configured via +api_call_log+ (YAML or Client kwargs).
  # Failures while saving never raise into application code.
  #
  # Column map (+columns+ hash): every +source_key => db_column+ entry is a whitelist. If +attrs+
  # includes +source_key+, its value is copied to the row (after optional coercion). This allows
  # app-specific passthrough keys (e.g. +bill_forward_event_id+) without extending the gem enum.
  #
  # Documented source keys populated by Connection/resources: +method+, +path+, +status+, +http_status+,
  # +duration_ms+, +request_body+, +response_body+, +error_class+, +error_message+, +streaming+,
  # +endpoint+, +logical_model+, +generation_id+, +success+, +cost+, +usage+, +request_json+,
  # +response_json+.
  class ApiCallLogger
    DEFAULT_MAX_BODY_BYTES = 65_536

    # Reserved keys in api_call_log YAML — never treated as column sources.
    RESERVED_CONFIG_KEYS = %w[model columns max_body_bytes chat_attempts responses_attempts].freeze

    # Keys the gem may set automatically (subset); full set is any key allowed in +columns+.
    CANONICAL_KEYS = %w[
      method path status http_status duration_ms request_body response_body error_class error_message streaming
      endpoint logical_model generation_id success cost usage request_json response_json
    ].freeze

    class << self
      def format_body_for_log(obj, max_bytes: DEFAULT_MAX_BODY_BYTES)
        str =
          case obj
          when nil then +""
          when String then obj.b
          else
            JSON.generate(obj)
          end
        str = redact_secrets(str)
        truncate_bytes(str, max_bytes)
      end

      def generation_id_from(response:, parsed_body:)
        h = response.respond_to?(:headers) ? response.headers : nil
        if h
          raw = h["x-generation-id"] || h["X-Generation-Id"] || h["X-GENERATION-ID"]
          gid = blank_to_nil(raw&.to_s)
          return gid if gid
        end
        return unless parsed_body.is_a?(Hash)

        blank_to_nil((parsed_body[:id] || parsed_body["id"]).to_s)
      end

      def blank_to_nil(raw)
        t = raw.to_s.strip
        t.empty? ? nil : t
      end

      # Best-effort OpenRouter-style error.message for JSON error bodies (symbol or string keys).
      def error_message_from_response_body(body)
        return unless body.is_a?(Hash)

        err = body[:error] || body["error"]
        case err
        when Hash
          blank_to_nil((err[:message] || err["message"]).to_s)
        when String
          blank_to_nil(err)
        end
      end

      def error_message_from_json_string(str)
        return unless str.is_a?(String)

        stripped = str.strip
        return unless stripped.start_with?("{", "[")

        parsed = JSON.parse(stripped, symbolize_names: true)
        error_message_from_response_body(parsed) if parsed.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end

      def cost_from_usage(usage)
        return unless usage.is_a?(Hash)

        u = usage.transform_keys(&:to_s)
        v = u["cost"] || u["total_cost"]
        return if v.nil?

        BigDecimal(v.to_s)
      rescue ArgumentError
        nil
      end

      private

      def redact_secrets(str)
        s = str.dup
        s.gsub!(/sk-or-v1-[A-Za-z0-9_-]+/, "sk-or-v1-[REDACTED]")
        s.gsub!(/Bearer\s+[A-Za-z0-9._-]+/i, "Bearer [REDACTED]")
        s
      end

      def truncate_bytes(str, max_bytes)
        return str if str.bytesize <= max_bytes

        "#{str.byteslice(0, max_bytes)}…(truncated)"
      end
    end

    def initialize(config)
      @config = config.is_a?(Hash) ? Configuration.stringify_keys_static(config) : {}
    end

    def enabled?
      m = @config["model"]
      !m.nil? && !m.to_s.strip.empty? &&
        @config["columns"].is_a?(Hash) && !@config["columns"].empty?
    end

    def max_body_limit
      n = @config["max_body_bytes"]
      n.is_a?(Integer) && n.positive? ? n : DEFAULT_MAX_BODY_BYTES
    end

    def chat_attempts_final?
      @config["chat_attempts"].to_s == "final"
    end

    def responses_attempts_final?
      @config["responses_attempts"].to_s == "final"
    end

    # +attrs+ string-keyed hashes; column mapping selects and renames fields for +create!+.
    def record(attrs)
      return unless enabled?

      row = build_row(attrs)
      return if row.empty?

      constantize_model(@config["model"].to_s.strip).create!(row)
    rescue StandardError => e
      warn "[savvy_openrouter] api_call_log skipped: #{e.class}: #{e.message}" if $VERBOSE
      nil
    end

    private

    def build_row(attrs)
      cols = @config["columns"] || {}
      attrs = Configuration.stringify_keys_static(attrs)
      lim = max_body_limit

      cols.each_with_object({}) do |(source_key, column_name), acc|
        sk = source_key.to_s
        next if RESERVED_CONFIG_KEYS.include?(sk)
        next unless attrs.key?(sk)

        acc[column_name.to_s] = coerce_value(sk, attrs[sk], lim)
      end
    end

    def coerce_value(source_key, val, lim)
      case source_key
      when "request_json", "response_json", "usage"
        val.nil? ? nil : self.class.format_body_for_log(val, max_bytes: lim)
      when "error_message"
        val.nil? ? nil : self.class.format_body_for_log(val.to_s, max_bytes: lim)
      when "success"
        coerce_success(val)
      when "cost"
        coerce_cost(val)
      when "http_status", "status"
        val.is_a?(Integer) ? val : Integer(val, exception: false) || val
      else
        val
      end
    end

    def coerce_success(val)
      return nil if val.nil?
      return val if [true, false].include?(val)

      val ? true : false
    end

    def coerce_cost(val)
      return nil if val.nil?
      return val if val.is_a?(BigDecimal)

      BigDecimal(val.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    def constantize_model(name)
      raise NameError, "blank model" if name.empty?
      raise NameError, "invalid model name #{name.inspect}" if name.include?("..") || /[^A-Za-z0-9_:]/.match?(name)

      parts = name.delete_prefix("::").split("::")
      parts.reduce(Object) { |mod, piece| mod.const_get(piece) }
    end
  end
end
