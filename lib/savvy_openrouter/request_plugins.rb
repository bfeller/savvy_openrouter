# frozen_string_literal: true

require "uri"
require_relative "patterns/structured_output"

module SavvyOpenrouter
  # Optional chat / Responses request shaping (OpenRouter plugins). Pure Ruby.
  #
  #   require "savvy_openrouter/request_plugins"
  #   SavvyOpenrouter::RequestPlugins.prepare_chat_body!(body, pdf_engine: "native")
  module RequestPlugins
    RESPONSE_HEALING_PLUGIN = { id: "response-healing" }.freeze
    FILE_PARSER_DEFAULT_ENGINE = "cloudflare-ai"

    module_function

    def prepare_chat_body!(body, pdf_engine: nil)
      return body unless body.is_a?(Hash)

      ensure_response_healing_for_chat!(body) if SavvyOpenrouter::Patterns.chat_structured_requested?(body)
      ensure_pdf_file_parser_plugin!(body, pdf_engine: pdf_engine)
      body
    end

    def prepare_responses_body!(body)
      return body unless body.is_a?(Hash)

      ensure_response_healing_for_responses!(body) if SavvyOpenrouter::Patterns.responses_structured_requested?(body)
      body
    end

    def ensure_response_healing_for_chat!(body)
      plugins_arr = plugins_array_from(body)
      return if response_healing_plugin_present?(plugins_arr)

      body[:plugins] = plugins_arr + [RESPONSE_HEALING_PLUGIN.dup]
      body.delete("plugins")
    end

    def ensure_response_healing_for_responses!(body)
      plugins_arr = plugins_array_from(body)
      return if response_healing_plugin_present?(plugins_arr)

      body[:plugins] = plugins_arr + [RESPONSE_HEALING_PLUGIN.dup]
      body.delete("plugins")
    end

    def plugins_array_from(body)
      p = body[:plugins] || body["plugins"]
      p.is_a?(Array) ? p.dup : []
    end

    def response_healing_plugin_present?(plugins)
      plugin_present?(plugins, id: "response-healing")
    end

    # +pdf_engine+ — optional override (e.g. from config: +"native"+ for Gemini, +"mistral-ocr"+ for scans).
    # When nil, uses {FILE_PARSER_DEFAULT_ENGINE}.
    def ensure_pdf_file_parser_plugin!(body, pdf_engine: nil)
      messages = body[:messages] || body["messages"]
      return unless chat_messages_include_pdf_attachment?(messages)

      engine = normalize_pdf_engine(pdf_engine)
      plugins = plugins_array_from(body)
      idx = plugins.find_index { |p| plugin_entry_id(p) == "file-parser" }

      if idx
        return if file_parser_pdf_engine_set?(plugins[idx])

        fp = plugins[idx].dup
        pdf_src = fp[:pdf] || fp["pdf"]
        merged_pdf =
          if pdf_src.is_a?(Hash)
            pdf_src.transform_keys(&:to_sym)
          else
            {}
          end
        merged_pdf[:engine] = engine
        fp[:pdf] = merged_pdf
        fp.delete("pdf")
        plugins[idx] = fp
        body[:plugins] = plugins
      else
        body[:plugins] = plugins + [{ id: "file-parser", pdf: { engine: engine } }]
      end
      body.delete("plugins")
    end

    def normalize_pdf_engine(pdf_engine)
      s = pdf_engine.to_s.strip
      s.empty? ? FILE_PARSER_DEFAULT_ENGINE : s
    end

    def chat_messages_include_pdf_attachment?(messages)
      return false unless messages.is_a?(Array)

      messages.any? { |msg| message_includes_pdf_file?(msg) }
    end

    def message_includes_pdf_file?(msg)
      return false unless msg.is_a?(Hash)

      content = msg[:content] || msg["content"]
      return false unless content.is_a?(Array)

      content.any? { |part| content_part_is_pdf_file?(part) }
    end

    def content_part_is_pdf_file?(part)
      return false unless part.is_a?(Hash)

      type = (part[:type] || part["type"]).to_s
      return false unless type == "file"

      file = part[:file] || part["file"]
      return false unless file.is_a?(Hash)

      pdf_file_attachment?(file)
    end

    def pdf_file_attachment?(file)
      name = (file[:filename] || file["filename"]).to_s
      return true if name.match?(/\.pdf\z/i)

      data = file[:file_data] || file["file_data"] || file[:fileData] || file["fileData"]
      return false unless data.is_a?(String)

      return true if data.match?(%r{\Adata:application/pdf(?:;|\z)}i)

      pdf_url?(data)
    end

    def pdf_url?(url)
      return false unless url.match?(%r{\Ahttps?://}i)

      uri = URI.parse(url)
      uri.path.to_s.match?(/\.pdf\z/i)
    rescue URI::InvalidURIError
      false
    end

    def file_parser_pdf_engine_set?(plugin)
      return false unless plugin.is_a?(Hash)

      pdf = plugin[:pdf] || plugin["pdf"]
      return false unless pdf.is_a?(Hash)

      eng = (pdf[:engine] || pdf["engine"]).to_s
      !eng.strip.empty?
    end

    def plugin_present?(plugins, id:)
      return false unless plugins.is_a?(Array)

      plugins.any? { |p| plugin_entry_id(p) == id.to_s }
    end

    def plugin_entry_id(entry)
      return unless entry.is_a?(Hash)

      (entry[:id] || entry["id"]).to_s
    end
  end
end
