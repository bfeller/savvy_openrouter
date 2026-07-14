# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Models < Base
      # Query params match OpenRouter GET /models (e.g. category, output_modalities, supported_parameters).
      def list(**params)
        query = stringify_query(params)
        conn.with_call_context(endpoint: "models", logical_model: nil) do
          conn.get("/models", params: query.empty? ? nil : query)
        end
      end

      # Uses GET /models with category + free-price filters, then returns the first model whose prompt and
      # completion pricing are both zero. OpenRouter returns models in curated rank order; the first free
      # match aligns with site “top free” picks when combined with output_modalities=text.
      # Models scheduled for removal (expiration_date) are still eligible — callers often want the current
      # top free pick even when it is temporary.
      def first_ranked_free_text_model(category:, output_modalities: "text")
        res = list(category: category, output_modalities: output_modalities, max_price: 0)
        data = res[:data] || []
        data.find { |m| free_pricing?(m) }
      end

      def count
        conn.with_call_context(endpoint: "models_count", logical_model: nil) do
          conn.get("/models/count")
        end
      end

      def user
        conn.with_call_context(endpoint: "models_user", logical_model: nil) do
          conn.get("/models/user")
        end
      end

      def endpoints(author:, slug:)
        conn.with_call_context(endpoint: "models_endpoints", logical_model: nil) do
          conn.get("/models/#{author}/#{slug}/endpoints")
        end
      end

      private

      def stringify_query(params)
        params.each_with_object({}) do |(k, v), acc|
          next if v.nil?

          acc[k.to_s] = v
        end
      end

      def free_pricing?(model)
        p = model[:pricing] || {}
        zero_price?(p[:prompt]) && zero_price?(p[:completion])
      end

      def zero_price?(value)
        return false if value.nil?

        value.to_s.gsub(/[^\d.\-eE]/, "").to_f.zero?
      end
    end
  end
end
