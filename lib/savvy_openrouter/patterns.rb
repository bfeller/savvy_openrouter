# frozen_string_literal: true

# Opt-in helpers for structured JSON validation after successful HTTP responses.
#
#   require "savvy_openrouter/patterns"
#   SavvyOpenrouter::Patterns.validate_after_success!(endpoint: "chat_completions", request: body, response: json)
#
# Raises {SavvyOpenrouter::StructuredOutputError} (+reason+, +response_body+).
require_relative "patterns/structured_output"
