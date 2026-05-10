# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Audio < Base
      def speech(**params)
        body = config.merge_chat_body(params)
        conn.post_raw("/audio/speech", body: body)
      end

      def transcribe(**params)
        body = config.merge_chat_body(params)
        conn.post("/audio/transcriptions", body: body)
      end
    end
  end
end
