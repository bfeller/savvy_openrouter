# frozen_string_literal: true

module SavvyOpenrouter
  module Resources
    class Base
      def initialize(client)
        @client = client
      end

      private

      attr_reader :client

      def logical_model_from_body(body)
        return nil unless body.is_a?(Hash)

        m = body[:model] || body["model"]
        s = m.to_s.strip
        s.empty? ? nil : s
      end

      def conn
        client.connection
      end

      def config
        client.config
      end
    end
  end
end
