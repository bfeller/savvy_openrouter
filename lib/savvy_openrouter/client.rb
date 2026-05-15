# frozen_string_literal: true

require_relative "configuration"
require_relative "connection"
require_relative "resources/chat"
require_relative "resources/responses"
require_relative "resources/anthropic_messages"
require_relative "resources/embeddings"
require_relative "resources/rerank"
require_relative "resources/models"
require_relative "resources/credits"
require_relative "resources/providers"
require_relative "resources/generations"
require_relative "resources/endpoints"
require_relative "resources/analytics"
require_relative "resources/audio"
require_relative "resources/videos"
require_relative "resources/oauth"
require_relative "resources/api_keys"
require_relative "resources/organization"
require_relative "resources/guardrails"
require_relative "resources/workspaces"

module SavvyOpenrouter
  class Client
    attr_reader :config, :connection

    # Optional DB-backed request logging; see README (+api_call_log+).
    def api_call_logger
      connection.api_call_logger
    end

    # Merge active +with_call_context+ stack attrs and persist one row (e.g. structured-output failure after HTTP 200).
    def record_api_call(attrs)
      connection.record_manual_api_call(attrs)
    end

    def initialize(config_path: nil, **options)
      @config = Configuration.new(config_path: config_path, **options)
      @connection = Connection.new(@config)
    end

    def chat
      @chat ||= Resources::Chat.new(self)
    end

    def responses
      @responses ||= Resources::Responses.new(self)
    end

    def anthropic_messages
      @anthropic_messages ||= Resources::AnthropicMessages.new(self)
    end

    def embeddings
      @embeddings ||= Resources::Embeddings.new(self)
    end

    def rerank
      @rerank ||= Resources::Rerank.new(self)
    end

    def models
      @models ||= Resources::Models.new(self)
    end

    def credits
      @credits ||= Resources::Credits.new(self)
    end

    def providers
      @providers ||= Resources::Providers.new(self)
    end

    def generations
      @generations ||= Resources::Generations.new(self)
    end

    def endpoints
      @endpoints ||= Resources::Endpoints.new(self)
    end

    def analytics
      @analytics ||= Resources::Analytics.new(self)
    end

    def audio
      @audio ||= Resources::Audio.new(self)
    end

    def videos
      @videos ||= Resources::Videos.new(self)
    end

    def oauth
      @oauth ||= Resources::OAuth.new(self)
    end

    def api_keys
      @api_keys ||= Resources::ApiKeys.new(self)
    end

    def organization
      @organization ||= Resources::Organization.new(self)
    end

    def guardrails
      @guardrails ||= Resources::Guardrails.new(self)
    end

    def workspaces
      @workspaces ||= Resources::Workspaces.new(self)
    end
  end
end
