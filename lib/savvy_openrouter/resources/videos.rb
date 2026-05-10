# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Videos < Base
      TERMINAL_STATUSES = %w[completed failed cancelled expired].freeze

      def create(**params)
        body = config.merge_video_body(params)
        conn.post("/videos", body: body)
      end

      alias submit create

      def get(job_id)
        conn.get("/videos/#{job_id}")
      end

      alias retrieve get
      alias poll get

      def download(job_id, index: 0)
        conn.get_raw("/videos/#{job_id}/content", params: { index: index })
      end

      def stream(job_id, index: 0, &block)
        raise ArgumentError, "block required" unless block

        conn.stream_get("/videos/#{job_id}/content", params: { index: index }, &block)
      end

      def poll_until(job_id, interval: 2, timeout: 600)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        loop do
          res = get(job_id)
          st = res[:status].to_s
          return res if TERMINAL_STATUSES.include?(st)

          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise TimeoutPollError, "Timed out waiting for video job #{job_id}" if now > deadline

          sleep(interval)
        end
      end

      def models
        conn.get("/videos/models")
      end
    end
  end
end
