# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Embeddings < Base
      def create(**params)
        body = config.merge_chat_body(params)
        lm = logical_model_from_body(body)
        conn.with_call_context(endpoint: "embeddings", logical_model: lm) do
          conn.post("/embeddings", body: body)
        end
      end

      def models
        conn.with_call_context(endpoint: "embeddings_models", logical_model: nil) do
          conn.get("/embeddings/models")
        end
      end
    end
  end
end
