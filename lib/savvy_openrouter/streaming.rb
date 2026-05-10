# frozen_string_literal: true

module SavvyOpenrouter
  module Streaming
    extend self

    # Yields each SSE `data:` payload line (without `data:` prefix), skipping `[DONE]`.
    def each_sse_data(chunk_enum, &block)
      buffer = +""
      chunk_enum.each do |chunk|
        buffer << chunk
        flush_sse!(buffer, &block)
      end
    end

    private

    def flush_sse!(buffer, &block)
      while (idx = buffer.index("\n\n"))
        blob = buffer.slice!(0..(idx + 1))
        blob.each_line do |line|
          line = line.strip
          next if line.empty?
          next unless line.start_with?("data:")

          payload = line.sub(/\Adata:\s*/, "")
          block.call(payload) unless payload == "[DONE]"
        end
      end
    end
  end
end
