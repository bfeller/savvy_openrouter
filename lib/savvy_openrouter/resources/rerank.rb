# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Rerank < Base
      def create(**params)
        body = config.merge_chat_body(params)
        conn.post("/rerank", body: body)
      end
    end
  end
end
