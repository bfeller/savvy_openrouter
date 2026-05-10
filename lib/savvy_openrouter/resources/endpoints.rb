# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Endpoints < Base
      def zdr(**params)
        conn.get("/endpoints/zdr", params: params)
      end
    end
  end
end
