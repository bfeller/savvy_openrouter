# frozen_string_literal: true

require "json"
require_relative "../structured_output_error"

module SavvyOpenrouter
  # Post-success validators for structured JSON (chat + Responses). Pure Ruby; use via +require "savvy_openrouter/patterns"+.
  # rubocop:disable Metrics/ModuleLength -- single cohesive module for optional require path
  module Patterns
    module_function

    def validate_after_success!(endpoint:, request:, response:)
      return unless response.is_a?(Hash)

      json = deep_stringify_keys(response)

      case endpoint.to_s
      when "chat_completions"
        validate_chat!(request, json)
      when "responses"
        validate_responses!(request, json)
      end
    end

    def validate_chat!(request_hash, json)
      return unless chat_structured_requested?(request_hash)

      choices = json["choices"]
      unless choices.is_a?(Array) && !choices.empty?
        raise StructuredOutputError.new("No choices in chat completion", reason: :no_choices, response_body: json)
      end

      choice = choices.first
      msg = choice["message"]
      unless msg.is_a?(Hash)
        raise StructuredOutputError.new("Missing assistant message", reason: :no_choices, response_body: json)
      end

      return if tool_calls_present?(msg)

      text = extract_chat_assistant_text(msg)
      if text.strip.empty?
        raise StructuredOutputError.new(
          "Structured output was requested but assistant message content is empty",
          reason: :empty_content,
          response_body: json
        )
      end

      assert_parseable_json!(text, json)
    end

    def validate_responses!(request_hash, json)
      return unless responses_structured_requested?(request_hash)

      text = extract_responses_output_text(json)
      if text.strip.empty?
        raise StructuredOutputError.new(
          "Structured output was requested but Responses API returned no parseable text output",
          reason: :empty_content,
          response_body: json
        )
      end

      assert_parseable_json!(text, json)
    end

    def chat_structured_requested?(body)
      return false unless body.is_a?(Hash)

      rf = body[:response_format] || body["response_format"]
      return false unless rf.is_a?(Hash)

      t = (rf[:type] || rf["type"]).to_s
      %w[json_schema json_object].include?(t)
    end

    def responses_structured_requested?(body)
      return false unless body.is_a?(Hash)

      text = body[:text] || body["text"]
      return false unless text.is_a?(Hash)

      fmt = text[:format] || text["format"]
      return false unless fmt.is_a?(Hash)

      t = (fmt[:type] || fmt["type"]).to_s
      %w[json_schema json_object].include?(t)
    end

    def extract_chat_assistant_text(msg)
      msg = deep_stringify_keys(msg) if msg.is_a?(Hash)
      c = msg["content"]
      case c
      when String
        c
      when Array
        c.filter_map do |p|
          next unless p.is_a?(Hash)

          txt = p["text"]
          p["type"].to_s == "text" && txt.is_a?(String) && !txt.strip.empty? ? txt : nil
        end.join
      else
        ""
      end
    end

    def extract_responses_output_text(payload)
      payload = deep_stringify_keys(payload) if payload.is_a?(Hash)
      return "" unless payload.is_a?(Hash)

      ot = payload["output_text"]
      return ot.to_s if ot.is_a?(String) && !ot.strip.empty?

      outputs = payload["output"]
      return "" unless outputs.is_a?(Array)

      texts = []
      outputs.each do |item|
        next unless item.is_a?(Hash)

        content = item["content"]
        next unless content.is_a?(Array)

        content.each do |part|
          next unless part.is_a?(Hash)
          next unless part["type"].to_s == "output_text"

          texts << part["text"].to_s
        end
      end
      texts.join
    end

    def assert_parseable_json!(text, response_json)
      stripped = text.strip
      begin
        JSON.parse(stripped)
      rescue JSON::ParserError => e
        fenced = stripped[/```(?:json)?\s*([\s\S]*?)```/mi, 1]
        if fenced && !fenced.strip.empty?
          begin
            return JSON.parse(fenced.strip)
          rescue JSON::ParserError => e2
            err = StructuredOutputError.new(
              "Structured output was requested but message content is not valid JSON (#{e2.message})",
              reason: :invalid_json,
              response_body: response_json
            )
            raise err, cause: e2
          end
        end

        err = StructuredOutputError.new(
          "Structured output was requested but message content is not valid JSON (#{e.message})",
          reason: :invalid_json,
          response_body: response_json
        )
        raise err, cause: e
      end
    end

    def deep_stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), h|
          h[k.to_s] = deep_stringify_keys(v)
        end
      when Array
        obj.map { |v| deep_stringify_keys(v) }
      else
        obj
      end
    end

    def tool_calls_present?(msg)
      tc = msg["tool_calls"]
      tc.is_a?(Array) && !tc.empty?
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
