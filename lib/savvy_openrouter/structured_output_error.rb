# frozen_string_literal: true

module SavvyOpenrouter
  # Raised when json_object/json_schema was requested but the successful response body
  # does not contain usable JSON in assistant/output text. Optional +require "savvy_openrouter/patterns"+.
  #
  # reason: +:empty_content+, +:invalid_json+, +:no_choices+
  class StructuredOutputError < StandardError
    attr_reader :reason, :response_body

    def initialize(message, reason:, response_body: nil)
      @reason = reason
      @response_body = response_body
      super(message)
    end
  end
end
