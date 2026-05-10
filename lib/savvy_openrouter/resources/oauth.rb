# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class OAuth < Base
      def exchange(**body)
        conn.post("/auth/keys", body: body)
      end

      def create_auth_code(**body)
        conn.post("/auth/keys/code", body: body)
      end
    end
  end
end
