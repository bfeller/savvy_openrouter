# frozen_string_literal: true

module SavvyOpenrouter
  # Controls optional retries for +Chat#completions+ (non-streaming): empty/zero-token
  # completions and selected HTTP errors from OpenRouter.
  class CompletionRetryPolicy
    DEFAULT_ON = {
      "zero_completion_tokens" => true,
      "empty_assistant_content" => true,
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
          raise ArgumentError, "chat_retries must be a Hash or false"
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

      (on?("zero_completion_tokens") && zero_completion_tokens?(response)) ||
        (on?("empty_assistant_content") && empty_assistant_content?(response))
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
      merged_on[key.to_s] == true
    end

    def merged_on
      @merged_on ||= DEFAULT_ON.merge(explicit_on)
    end

    def explicit_on
      h = @raw["on"]
      h.is_a?(Hash) ? Configuration.stringify_keys_static(h) : {}
    end

    def zero_completion_tokens?(response)
      usage = dig_usage(response)
      return false unless usage

      ct = usage[:completion_tokens] || usage["completion_tokens"]
      ct.nil? ? false : ct.to_i.zero?
    end

    def empty_assistant_content?(response)
      msg = first_assistant_message(response)
      return false unless msg

      tool_calls = msg[:tool_calls] || msg["tool_calls"]
      return false if tool_calls.is_a?(Array) && !tool_calls.empty?

      content = msg[:content] || msg["content"]
      return true if content.nil?

      !content.is_a?(String) || content.strip.empty?
    end

    def dig_usage(response)
      response[:usage] || response["usage"]
    end

    def first_assistant_message(response)
      choices = response[:choices] || response["choices"]
      return nil unless choices.is_a?(Array) && choices.first

      choice = choices.first
      choice[:message] || choice["message"]
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
