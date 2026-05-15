# frozen_string_literal: true

require "spec_helper"

RSpec.describe SavvyOpenrouter::Resources::Generations do
  let(:client) { SavvyOpenrouter::Client.new(api_key: "sk-test") }
  let(:generations) { client.generations }

  describe "#get" do
    it "returns generation metadata for the given id" do
      stub_request(:get, "https://openrouter.ai/api/v1/generation")
        .with(query: { id: "gen-abc" })
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            data: {
              id: "gen-abc",
              total_cost: 0.001,
              tokens_prompt: 10,
              tokens_completion: 5
            }
          }.to_json
        )

      result = generations.get(id: "gen-abc")
      expect(result[:data][:id]).to eq("gen-abc")
      expect(result[:data][:total_cost]).to eq(0.001)
    end
  end
end
