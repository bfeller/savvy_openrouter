# frozen_string_literal: true

module SavvyOpenrouter
  module Resources
    class Base
      def initialize(client)
        @client = client
      end

      private

      attr_reader :client

      def conn
        client.connection
      end

      def config
        client.config
      end
    end
  end
end
