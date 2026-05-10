# frozen_string_literal: true

require "yaml"

module SavvyOpenrouter
  class Configuration
    attr_accessor :api_key, :base_url, :default_model, :http_referer, :app_title
    attr_reader :defaults, :video_defaults, :responses_defaults, :api_call_log, :chat_retries

    alias llm_model default_model
    alias llm_model= default_model=

    def self.load_file(path)
      return {} unless path && File.file?(path)

      data = YAML.safe_load(File.read(path), permitted_classes: [], permitted_symbols: [], aliases: true)
      data.is_a?(Hash) ? stringify_keys_static(data) : {}
    end

    def self.stringify_keys_static(hash)
      hash.each_with_object({}) do |(k, v), acc|
        acc[k.to_s] = v.is_a?(Hash) ? stringify_keys_static(v) : v
      end
    end

    # Precedence: explicit keyword args (highest) > YAML file > ENV (lowest).
    def initialize(config_path: nil, **options)
      @defaults = {}
      @video_defaults = {}
      @responses_defaults = {}
      @api_call_log = {}
      @chat_retries = {}
      load_from_env!
      yaml_path = config_path || self.class.discover_config_file
      merge_hash!(self.class.load_file(yaml_path)) if yaml_path
      apply_options!(options)
    end

    def self.discover_config_file(cwd = Dir.pwd)
      %w[config/savvy_openrouter.yml .savvy_openrouter.yml].each do |rel|
        path = File.join(cwd, rel)
        return path if File.file?(path)
      end
      nil
    end

    def merge_hash!(hash)
      return unless hash.is_a?(Hash)

      hash = self.class.stringify_keys_static(hash)
      @api_key = hash["api_key"] if hash.key?("api_key")
      @base_url = hash["base_url"] if hash.key?("base_url")
      @default_model = hash["default_model"] || hash["llm_model"] if hash.key?("default_model") || hash.key?("llm_model")
      @http_referer = hash["http_referer"] if hash.key?("http_referer")
      @app_title = hash["app_title"] || hash["x_title"] if hash.key?("app_title") || hash.key?("x_title")
      @defaults = @defaults.merge(self.class.stringify_keys_static(hash["defaults"] || {}))
      vd = hash["video_defaults"] || hash["defaults_video"]
      @video_defaults = @video_defaults.merge(self.class.stringify_keys_static(vd || {}))
      rd = hash["responses_defaults"] || hash["defaults_responses"]
      @responses_defaults = @responses_defaults.merge(self.class.stringify_keys_static(rd || {}))
      assign_api_call_log(hash["api_call_log"]) if hash.key?("api_call_log")
      assign_chat_retries(hash["chat_retries"]) if hash.key?("chat_retries")
      assign_chat_retries(hash["completion_retries"]) if hash.key?("completion_retries")
    end

    def merge_chat_body(body)
      body = stringify_keys(body)
      merged = @defaults.merge(body)
      merged["model"] ||= @default_model if @default_model && merged["model"].nil?
      merged
    end

    def merge_video_body(body)
      body = stringify_keys(body)
      merged = @video_defaults.merge(body)
      merged["model"] ||= @default_model if @default_model && merged["model"].nil?
      merged
    end

    # Defaults only for `POST /responses` (Responses API beta): `plugins`, `tools`,
    # `max_output_tokens`, `x_search_filter`, etc. Keeps web-search settings off chat/embeddings bodies.
    def merge_responses_body(body)
      body = stringify_keys(body)
      merged = @responses_defaults.merge(body)
      merged["model"] ||= @default_model if @default_model && merged["model"].nil?
      merged
    end

    private

    def load_from_env!
      @api_key = ENV.fetch("OPENROUTER_API_KEY", nil)
      @base_url = ENV.fetch("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1")
      @default_model = ENV.fetch("OPENROUTER_DEFAULT_MODEL", nil)
      @http_referer = ENV.fetch("OPENROUTER_HTTP_REFERER", nil)
      @app_title = ENV.fetch("OPENROUTER_APP_TITLE", nil)
    end

    def apply_options!(options)
      opts = options.dup
      @defaults = @defaults.merge(stringify_keys(opts.delete(:defaults) || {}))
      vd = opts.delete(:video_defaults) || opts.delete(:defaults_video)
      @video_defaults = @video_defaults.merge(stringify_keys(vd || {}))
      rd = opts.delete(:responses_defaults) || opts.delete(:defaults_responses)
      @responses_defaults = @responses_defaults.merge(stringify_keys(rd || {}))

      @api_key = opts.delete(:api_key) if opts.key?(:api_key)
      @base_url = opts.delete(:base_url) if opts.key?(:base_url)
      if opts.key?(:default_model) || opts.key?(:llm_model)
        @default_model = opts.delete(:default_model) || opts.delete(:llm_model)
      end
      @http_referer = opts.delete(:http_referer) if opts.key?(:http_referer)
      @app_title = opts.delete(:app_title) if opts.key?(:app_title)
      assign_api_call_log(opts.delete(:api_call_log)) if opts.key?(:api_call_log)
      if opts.key?(:chat_retries)
        assign_chat_retries(opts.delete(:chat_retries))
      elsif opts.key?(:completion_retries)
        assign_chat_retries(opts.delete(:completion_retries))
      end

      return if opts.empty?

      raise ArgumentError, "Unknown keywords: #{opts.keys.join(", ")}"
    end

    def stringify_keys(hash)
      self.class.stringify_keys_static(hash || {})
    end

    def assign_api_call_log(value)
      case value
      when false, nil
        @api_call_log = {}
      when Hash
        h = self.class.stringify_keys_static(value)
        h["columns"] = self.class.stringify_keys_static(h["columns"]) if h["columns"].is_a?(Hash)
        @api_call_log = h
      else
        raise ArgumentError, "api_call_log must be a Hash or false"
      end
    end

    def assign_chat_retries(value)
      case value
      when false, nil
        @chat_retries = {}
      when Hash
        h = self.class.stringify_keys_static(value)
        h["on"] = self.class.stringify_keys_static(h["on"]) if h["on"].is_a?(Hash)
        @chat_retries = h
      else
        raise ArgumentError, "chat_retries must be a Hash or false"
      end
    end
  end
end
