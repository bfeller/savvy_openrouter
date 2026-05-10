# frozen_string_literal: true

require "json"

module SavvyOpenrouter
  # Persists OpenRouter HTTP exchanges when configured via +api_call_log+ (YAML or Client kwargs).
  # Failures while saving never raise into application code.
  class ApiCallLogger
    DEFAULT_MAX_BODY_BYTES = 65_536

    CANONICAL_KEYS = %w[
      method path status duration_ms request_body response_body error_class error_message streaming
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

    # +attrs+ uses canonical string keys (see CANONICAL_KEYS). Column mapping is applied before create.
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
      cols.each_with_object({}) do |(canonical, column_name), acc|
        next unless CANONICAL_KEYS.include?(canonical.to_s)
        next unless attrs.key?(canonical.to_s)

        acc[column_name.to_s] = attrs[canonical.to_s]
      end
    end

    def constantize_model(name)
      raise NameError, "blank model" if name.empty?
      raise NameError, "invalid model name #{name.inspect}" if name.include?("..") || /[^A-Za-z0-9_:]/.match?(name)

      parts = name.delete_prefix("::").split("::")
      parts.reduce(Object) { |mod, piece| mod.const_get(piece) }
    end
  end
end
