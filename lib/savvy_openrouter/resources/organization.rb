# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Organization < Base
      def members
        conn.get("/organization/members")
      end
    end
  end
end
