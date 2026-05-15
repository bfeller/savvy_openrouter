# frozen_string_literal: true

module SavvyOpenrouter
  # Retries for +Resources::Responses#create+ (zero output tokens / selected HTTP errors).
  class ResponsesRetryPolicy
    DEFAULT_ON = {
      "zero_output_tokens" => true,
      "rate_limit" => true,
      "bad_gateway" => true,
      "internal_server_error" => true,
      "service_unavailable" => true
    }.freeze

    def initialize(raw)
      @raw =
        case raw
        when false, nil then {}
        when Hash then Configuration.stringify_keys_static(raw)
        else
          raise ArgumentError, "responses_retries must be a Hash or false"
        end
    end

    def max_attempts
      n = @raw["max_attempts"]
      i = Integer(n, exception: false)
      i&.positive? ? i : 1
    end

    def enabled?
      max_attempts > 1
    end

    def retry_http_error?(error)
      return false unless enabled?
      return false unless error.is_a?(SavvyOpenrouter::ApiError)

      code = error.status_code
      return false unless code

      flag =
        case code
        when 429 then "rate_limit"
        when 502 then "bad_gateway"
        when 500, 501 then "internal_server_error"
        when 503 then "service_unavailable"
        end
      flag ? on?(flag) : false
    end

    def retry_response?(response)
      return false unless enabled?

      on?("zero_output_tokens") && responses_zero_output_retry?(response)
    end

    def wait_after_attempt(attempt_number)
      base = integer_opt(@raw["base_delay_ms"], 400)
      max_d = integer_opt(@raw["max_delay_ms"], 10_000)
      exponential = @raw["exponential_backoff"] != false
      jitter_ratio = float_opt(@raw["jitter_ratio"], 0.15)

      delay_ms =
        if exponential
          base * (2**(attempt_number - 1))
        else
          base
        end
      delay_ms = [delay_ms, max_d].min
      jitter = jitter_ratio.clamp(0.0, 1.0) * delay_ms * rand
      sleep((delay_ms + jitter) / 1000.0)
    end

    private

    def on?(key)
      DEFAULT_ON.merge(explicit_on)[key.to_s] == true
    end

    def explicit_on
      h = @raw["on"]
      h.is_a?(Hash) ? Configuration.stringify_keys_static(h) : {}
    end

    # Aligns with OpenRouter zero-completion / empty Responses output heuristics.
    def responses_zero_output_retry?(json)
      return false unless json.is_a?(Hash)

      usage = json[:usage] || json["usage"]
      return false unless usage.is_a?(Hash)

      out = usage[:output_tokens] || usage["output_tokens"]
      return false if out.nil?
      return false if out.to_i.positive?

      status = (json[:status] || json["status"]).to_s
      return true if %w[failed cancelled incomplete queued in_progress].include?(status)

      status == "completed"
    end

    def integer_opt(val, default)
      i = Integer(val, exception: false)
      i&.positive? ? i : default
    end

    def float_opt(val, default)
      f = Float(val, exception: false)
      f.nil? || f.negative? ? default : f
    end
  end
end
