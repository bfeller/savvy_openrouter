# frozen_string_literal: true

require_relative "base"
require_relative "../responses_retry_policy"

module SavvyOpenrouter
  module Resources
    class Responses < Base
      def create(**params)
        policy = ResponsesRetryPolicy.new(config.responses_retries)
        body = config.merge_responses_body(params)
        lm = logical_model_from_body(body)
        conn.with_call_context(endpoint: "responses", logical_model: lm) do
          attempt = 0
          last_response = nil
          begin
            loop do
              attempt += 1
              begin
                last_response = conn.post("/responses", body: body)
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
            conn.flush_deferred_responses_log!
          end
        end
      end
    end
  end
end
