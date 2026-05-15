# frozen_string_literal: true

module SavvyOpenrouter
  class Connection
    # JSON Faraday exchanges + timing helpers for {api_call_log}.
    module ApiCallRecording
      private

      def record_faraday_json(method:, rel_path:, params:, request_body:, response:, duration_ms:)
        return if suppress_api_call_log?
        return unless @api_call_logger.enabled?

        attrs = merge_call_log_context(
          faraday_json_attrs(method: method, rel_path: rel_path, params: params, request_body: request_body,
                             response: response, duration_ms: duration_ms)
        )

        if defer_chat_completions_log?(method: method, rel_path: rel_path)
          @pending_deferred_chat_log = attrs
          return
        end

        if defer_responses_log?(method: method, rel_path: rel_path)
          @pending_deferred_responses_log = attrs
          return
        end

        @api_call_logger.record(attrs)
      end

      def faraday_json_attrs(method:, rel_path:, params:, request_body:, response:, duration_ms:)
        lim = @api_call_logger.max_body_limit
        body = response.body
        usage = usage_hash_from_body(body)
        status = response.status
        success = status.is_a?(Integer) && (200..299).include?(status)
        gid = ApiCallLogger.generation_id_from(response: response, parsed_body: body)
        cost = usage ? ApiCallLogger.cost_from_usage(usage) : nil
        lm = extract_logical_model_from_request(request_body)
        error_message =
          if success
            nil
          else
            ApiCallLogger.error_message_from_response_body(body)
          end

        {
          "method" => method,
          "path" => full_url(rel_path, params),
          "status" => status,
          "http_status" => status,
          "duration_ms" => duration_ms.round(3),
          "request_body" => ApiCallLogger.format_body_for_log(request_body, max_bytes: lim),
          "response_body" => ApiCallLogger.format_body_for_log(body, max_bytes: lim),
          "request_json" => request_body,
          "response_json" => body,
          "error_class" => nil,
          "error_message" => error_message,
          "streaming" => false,
          "success" => success,
          "generation_id" => gid,
          "usage" => usage,
          "cost" => cost,
          "logical_model" => lm
        }
      end

      def usage_hash_from_body(body)
        return unless body.is_a?(Hash)

        u = body[:usage] || body["usage"]
        u.is_a?(Hash) ? u : nil
      end

      def extract_logical_model_from_request(request_body)
        case request_body
        when Hash
          m = request_body[:model] || request_body["model"]
          s = m.to_s.strip
          s.empty? ? nil : s
        end
      end

      def full_url(rel_path, params)
        u = join_uri(rel_path)
        if params && !params.empty?
          flat = params.transform_keys(&:to_s)
          u.query = URI.encode_www_form(flat)
        end
        u.to_s
      end

      def monotonic_ms
        Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000
      end

      def elapsed_ms(started)
        monotonic_ms - started
      end
    end
  end
end
