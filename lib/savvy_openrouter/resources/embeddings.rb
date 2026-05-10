# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Embeddings < Base
      def create(**params)
        body = config.merge_chat_body(params)
        conn.post("/embeddings", body: body)
      end

      def models
        conn.get("/embeddings/models")
      end
    end
  end
end
