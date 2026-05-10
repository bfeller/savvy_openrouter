# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Credits < Base
      def get
        conn.get("/credits")
      end
    end
  end
end
