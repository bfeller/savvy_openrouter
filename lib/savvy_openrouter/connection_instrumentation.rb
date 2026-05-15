# frozen_string_literal: true

module SavvyOpenrouter
  class Connection
    # Timing + orchestration hooks for optional request logging ({api_call_log} config).
    module Instrumentation
      private

      def timed_json(method_sym, path, params: nil, body: nil, success: DEFAULT_SUCCESS)
        rel = rel_path(path)
        started = monotonic_ms
        response =
          case method_sym
          when :get then @conn.get(rel) { |req| req.params.update(params) if params }
          when :delete then @conn.delete(rel) { |req| req.params.update(params) if params }
          when :post then @conn.post(rel, body)
          when :patch then @conn.patch(rel, body)
          when :put then @conn.put(rel, body)
          else raise ArgumentError, "unsupported #{method_sym}"
          end
        duration_ms = elapsed_ms(started)
        record_faraday_json(
          method: method_sym.to_s.upcase,
          rel_path: rel,
          params: params,
          request_body: body,
          response: response,
          duration_ms: duration_ms
        )
        parse_json_response(response, success: success)
      rescue SavvyOpenrouter::ApiError
        raise
      rescue StandardError => e
        record_transport_error(method: method_sym.to_s.upcase, rel_path: rel, params: params, request_body: body,
                               duration_ms: elapsed_ms(started), error: e)
        raise
      end

      def defer_chat_completions_log?(method:, rel_path:)
        return false unless @api_call_logger.enabled?
        return false unless @api_call_logger.chat_attempts_final?
        return false unless method.to_s.upcase == "POST"
        return false unless rel_path.to_s.include?("chat/completions")

        true
      end

      def defer_responses_log?(method:, rel_path:)
        return false unless @api_call_logger.enabled?
        return false unless @api_call_logger.responses_attempts_final?
        return false unless method.to_s.upcase == "POST"

        rel = rel_path.to_s
        rel == "responses" || rel.end_with?("/responses")
      end

      def merge_call_log_context(base)
        ctx = Configuration.stringify_keys_static(@call_context_stack.last || {})
        Configuration.stringify_keys_static(base).merge(ctx)
      end

      def suppress_api_call_log?
        ctx = @call_context_stack.last || {}
        ctx["suppress_api_call_log"] == true || ctx[:suppress_api_call_log] == true
      end
    end
  end
end
