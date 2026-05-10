# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class ApiKeys < Base
      def current
        conn.get("/key")
      end

      def list(**params)
        conn.get("/keys", params: params)
      end

      def create(**body)
        conn.post("/keys", body: body, success: [201])
      end

      def get(hash)
        conn.get("/keys/#{hash}")
      end

      def update(hash, **body)
        conn.patch("/keys/#{hash}", body: body)
      end

      def delete(hash)
        conn.delete("/keys/#{hash}")
      end
    end
  end
end
