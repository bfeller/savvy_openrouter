# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Responses < Base
      def create(**params)
        body = config.merge_responses_body(params)
        conn.post("/responses", body: body)
      end
    end
  end
end
