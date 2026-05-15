# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Generations < Base
      def get(id:)
        conn.with_call_context(endpoint: "generation", logical_model: nil) do
          conn.get("/generation", params: { id: id })
        end
      end

      def content(**params)
        conn.with_call_context(endpoint: "generation_content", logical_model: nil) do
          conn.get("/generation/content", params: params)
        end
      end
    end
  end
end
