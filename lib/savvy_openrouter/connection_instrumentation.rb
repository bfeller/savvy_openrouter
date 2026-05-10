# frozen_string_literal: true

module SavvyOpenrouter
  class Connection
    # Timing + persistence hooks for optional request logging ({api_call_log} config).
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
        record_faraday_json(method: method_sym.to_s.upcase, rel_path: rel, params: params, request_body: body, response: response,
                            duration_ms: duration_ms)
        parse_json_response(response, success: success)
      rescue SavvyOpenrouter::ApiError
        raise
      rescue StandardError => e
        record_transport_error(method: method_sym.to_s.upcase, rel_path: rel, params: params, request_body: body,
                               duration_ms: elapsed_ms(started), error: e)
        raise
      end

      def record_faraday_json(method:, rel_path:, params:, request_body:, response:, duration_ms:)
        return unless @api_call_logger.enabled?

        lim = @api_call_logger.max_body_limit
        @api_call_logger.record(
          "method" => method,
          "path" => full_url(rel_path, params),
          "status" => response.status,
          "duration_ms" => duration_ms.round(3),
          "request_body" => ApiCallLogger.format_body_for_log(request_body, max_bytes: lim),
          "response_body" => ApiCallLogger.format_body_for_log(response.body, max_bytes: lim),
          "error_class" => nil,
          "error_message" => nil,
          "streaming" => false
        )
      end

      def record_faraday_raw(method:, rel_path:, params:, request_body:, response:, duration_ms:)
        return unless @api_call_logger.enabled?

        lim = @api_call_logger.max_body_limit
        body_for_resp =
          if response.body.is_a?(String) && response.body.encoding == Encoding::ASCII_8BIT
            "[binary #{response.body.bytesize} bytes]"
          else
            response.body
          end
        @api_call_logger.record(
          "method" => method,
          "path" => full_url(rel_path, params),
          "status" => response.status,
          "duration_ms" => duration_ms.round(3),
          "request_body" => ApiCallLogger.format_body_for_log(request_body, max_bytes: lim),
          "response_body" => ApiCallLogger.format_body_for_log(body_for_resp, max_bytes: lim),
          "error_class" => nil,
          "error_message" => nil,
          "streaming" => false
        )
      end

      def record_stream(method:, rel_path:, params:, request_body:, status:, response_body:, duration_ms:)
        return unless @api_call_logger.enabled?

        lim = @api_call_logger.max_body_limit
        preview =
          if status == 200
            "[stream completed]"
          else
            response_body
          end
        @api_call_logger.record(
          "method" => method,
          "path" => full_url(rel_path, params),
          "status" => status,
          "duration_ms" => duration_ms.round(3),
          "request_body" => ApiCallLogger.format_body_for_log(request_body, max_bytes: lim),
          "response_body" => ApiCallLogger.format_body_for_log(preview, max_bytes: lim),
          "error_class" => nil,
          "error_message" => nil,
          "streaming" => true
        )
      end

      def record_transport_error(method:, rel_path:, params:, request_body:, duration_ms:, error:)
        return unless @api_call_logger.enabled?

        lim = @api_call_logger.max_body_limit
        msg = ApiCallLogger.format_body_for_log(error.message, max_bytes: lim)

        @api_call_logger.record(
          "method" => method,
          "path" => full_url(rel_path, params),
          "status" => nil,
          "duration_ms" => duration_ms.round(3),
          "request_body" => ApiCallLogger.format_body_for_log(request_body, max_bytes: lim),
          "response_body" => "",
          "error_class" => error.class.name,
          "error_message" => msg,
          "streaming" => false
        )
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
