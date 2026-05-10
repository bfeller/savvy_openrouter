# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Analytics < Base
      def activity(**params)
        conn.get("/activity", params: params)
      end
    end
  end
end
