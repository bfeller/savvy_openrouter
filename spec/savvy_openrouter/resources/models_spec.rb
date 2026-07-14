# frozen_string_literal: true

require "spec_helper"

RSpec.describe SavvyOpenrouter::Resources::Models do
  let(:client) { SavvyOpenrouter::Client.new(api_key: "k") }

  describe "#list" do
    it "forwards query params to GET /models" do
      stub_request(:get, "https://openrouter.ai/api/v1/models")
        .with(query: hash_including("category" => "programming", "output_modalities" => "text"))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: '{"data":[{"id":"x/y"}]}'
        )

      res = client.models.list(category: "programming", output_modalities: "text")
      expect(res[:data].first[:id]).to eq("x/y")
    end
  end

  describe "#first_ranked_free_text_model" do
    it "requests free models and returns the first zero-priced model in API order" do
      body = {
        data: [
          { id: "tencent/hy3:free", pricing: { prompt: "0", completion: "0" }, expiration_date: "2026-07-21" },
          { id: "other/free:free", pricing: { prompt: "0", completion: "0" } }
        ]
      }
      stub_request(:get, "https://openrouter.ai/api/v1/models")
        .with(query: hash_including(
          "category" => "programming",
          "output_modalities" => "text",
          "max_price" => "0"
        ))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: JSON.generate(body)
        )

      m = client.models.first_ranked_free_text_model(category: "programming")
      expect(m[:id]).to eq("tencent/hy3:free")
    end
  end
end
