# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Generations < Base
      def get(id:)
        conn.get("/generation", params: { id: id })
      end

      def content(**params)
        conn.get("/generation/content", params: params)
      end
    end
  end
end
