# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Providers < Base
      def list
        conn.get("/providers")
      end
    end
  end
end
