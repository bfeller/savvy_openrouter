# frozen_string_literal: true

module SavvyOpenrouter
  class Connection
    # Raw, streaming, and transport-error rows for {api_call_log}.
    module ApiCallRecordingTransport
      private

      def record_faraday_raw(method:, rel_path:, params:, request_body:, response:, duration_ms:)
        return if suppress_api_call_log?
        return unless @api_call_logger.enabled?

        lim = @api_call_logger.max_body_limit
        status = response.status
        success = status.is_a?(Integer) && (200..299).include?(status)
        body_for_resp =
          if response.body.is_a?(String) && response.body.encoding == Encoding::ASCII_8BIT
            "[binary #{response.body.bytesize} bytes]"
          else
            response.body
          end
        error_message = error_message_for_raw_response(success, body_for_resp)
        attrs = merge_call_log_context(
          {
            "method" => method,
            "path" => full_url(rel_path, params),
            "status" => status,
            "http_status" => status,
            "duration_ms" => duration_ms.round(3),
            "request_body" => ApiCallLogger.format_body_for_log(request_body, max_bytes: lim),
            "response_body" => ApiCallLogger.format_body_for_log(body_for_resp, max_bytes: lim),
            "request_json" => request_body,
            "response_json" => (body_for_resp.is_a?(Hash) ? body_for_resp : nil),
            "error_class" => nil,
            "error_message" => error_message,
            "streaming" => false,
            "success" => success
          }
        )
        @api_call_logger.record(attrs)
      end

      def record_stream(method:, rel_path:, params:, request_body:, status:, response_body:, duration_ms:)
        return if suppress_api_call_log?
        return unless @api_call_logger.enabled?

        lim = @api_call_logger.max_body_limit
        preview =
          if status == 200
            "[stream completed]"
          else
            response_body
          end
        ok = status.is_a?(Integer) && (200..299).include?(status)
        error_message = error_message_for_raw_response(ok, preview)
        attrs = merge_call_log_context(
          {
            "method" => method,
            "path" => full_url(rel_path, params),
            "status" => status,
            "http_status" => status,
            "duration_ms" => duration_ms.round(3),
            "request_body" => ApiCallLogger.format_body_for_log(request_body, max_bytes: lim),
            "response_body" => ApiCallLogger.format_body_for_log(preview, max_bytes: lim),
            "error_class" => nil,
            "error_message" => error_message,
            "streaming" => true,
            "success" => ok
          }
        )
        @api_call_logger.record(attrs)
      end

      def record_transport_error(method:, rel_path:, params:, request_body:, duration_ms:, error:)
        return if suppress_api_call_log?
        return unless @api_call_logger.enabled?

        lim = @api_call_logger.max_body_limit
        msg = ApiCallLogger.format_body_for_log(error.message, max_bytes: lim)

        attrs = merge_call_log_context(
          {
            "method" => method,
            "path" => full_url(rel_path, params),
            "status" => nil,
            "http_status" => nil,
            "duration_ms" => duration_ms.round(3),
            "request_body" => ApiCallLogger.format_body_for_log(request_body, max_bytes: lim),
            "response_body" => "",
            "error_class" => error.class.name,
            "error_message" => msg,
            "streaming" => false,
            "success" => false
          }
        )
        @api_call_logger.record(attrs)
      end

      def error_message_for_raw_response(success, payload)
        return if success

        case payload
        when Hash
          ApiCallLogger.error_message_from_response_body(payload)
        when String
          ApiCallLogger.error_message_from_json_string(payload)
        end
      end
    end
  end
end
