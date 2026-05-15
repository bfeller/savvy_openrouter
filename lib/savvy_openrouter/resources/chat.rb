# frozen_string_literal: true

require_relative "base"
require_relative "../streaming"
require_relative "../completion_retry_policy"

module SavvyOpenrouter
  module Resources
    class Chat < Base
      def completions(messages:, **params)
        policy = CompletionRetryPolicy.new(config.chat_retries)
        body = config.merge_chat_body({ messages: messages }.merge(params))
        lm = logical_model_from_body(body)
        conn.with_call_context(endpoint: "chat_completions", logical_model: lm) do
          attempt = 0
          last_response = nil
          begin
            loop do
              attempt += 1
              begin
                last_response = conn.post("/chat/completions", body: body)
              rescue SavvyOpenrouter::ApiError => e
                raise e if attempt >= policy.max_attempts || !policy.retry_http_error?(e)

                policy.wait_after_attempt(attempt)
                next
              end

              return last_response unless policy.retry_response?(last_response)
              return last_response if attempt >= policy.max_attempts

              policy.wait_after_attempt(attempt)
            end
          ensure
            conn.flush_deferred_chat_log!
          end
        end
      end

      # Yields each SSE `data:` payload string (JSON text from the model stream).
      def completions_stream(messages:, **params, &block)
        body = config.merge_chat_body({ messages: messages, stream: true }.merge(params))
        lm = logical_model_from_body(body)
        conn.with_call_context(endpoint: "chat_completions", logical_model: lm) do
          return enum_for(:completions_stream, messages: messages, **params) unless block

          chunk_enum = Enumerator.new do |y|
            conn.stream_post("/chat/completions", body) { |ch| y << ch }
          end
          Streaming.each_sse_data(chunk_enum, &block)
        end
      end
    end
  end
end
