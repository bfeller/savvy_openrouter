# frozen_string_literal: true

require_relative "base"

module SavvyOpenrouter
  module Resources
    class Models < Base
      # Query params match OpenRouter GET /models (e.g. category, output_modalities, supported_parameters).
      def list(**params)
        query = stringify_query(params)
        conn.get("/models", params: query.empty? ? nil : query)
      end

      # Uses GET /models with filters, then returns the first model whose prompt + completion pricing are zero.
      # OpenRouter returns models in curated rank order within a category; first matching free model aligns with
      # site “top free” picks when combined with output_modalities=text.
      def first_ranked_free_text_model(category:, output_modalities: "text")
        res = list(category: category, output_modalities: output_modalities)
        data = res[:data] || []
        data.find { |m| free_pricing?(m) }
      end

      def count
        conn.get("/models/count")
      end

      def user
        conn.get("/models/user")
      end

      def endpoints(author:, slug:)
        conn.get("/models/#{author}/#{slug}/endpoints")
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
