# frozen_string_literal: true

require "spec_helper"

RSpec.describe SavvyOpenrouter::Resources::Responses do
  let(:client) { SavvyOpenrouter::Client.new(api_key: "sk-test") }
  let(:responses) { client.responses }

  describe "#create" do
    it "POSTs to /responses and returns parsed JSON" do
      stub_request(:post, "https://openrouter.ai/api/v1/responses")
        .with(body: hash_including("model" => "openai/gpt-4o", "input" => "Hello"))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { id: "resp-1", status: "completed", output: [] }.to_json
        )

      result = responses.create(model: "openai/gpt-4o", input: "Hello")
      expect(result[:id]).to eq("resp-1")
      expect(result[:status]).to eq("completed")
    end

    it "merges responses_defaults from configuration" do
      client = SavvyOpenrouter::Client.new(
        api_key: "sk-test",
        responses_defaults: { max_output_tokens: 9000 }
      )
      stub_request(:post, "https://openrouter.ai/api/v1/responses")
        .with(body: hash_including("max_output_tokens" => 9000, "input" => "Hi"))
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { id: "resp-2" }.to_json
        )

      client.responses.create(input: "Hi", model: "openai/gpt-4o")
    end

    it "raises PaymentRequiredError on 402" do
      stub_request(:post, "https://openrouter.ai/api/v1/responses")
        .to_return(
          status: 402,
          headers: { "Content-Type" => "application/json" },
          body: { error: { message: "Insufficient credits" } }.to_json
        )

      expect do
        responses.create(model: "openai/gpt-4o", input: "Hello")
      end.to raise_error(SavvyOpenrouter::PaymentRequiredError, /Insufficient credits/)
    end

    it "retries on zero output_tokens when responses_retries is configured" do
      stub_request(:post, "https://openrouter.ai/api/v1/responses")
        .to_return(
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { id: "a", status: "completed", usage: { output_tokens: 0 } }.to_json
          },
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { id: "b", status: "completed", usage: { output_tokens: 2, cost: 0.001 } }.to_json
          }
        )

      client = SavvyOpenrouter::Client.new(
        api_key: "sk-test",
        responses_retries: {
          max_attempts: 3,
          base_delay_ms: 0,
          jitter_ratio: 0,
          exponential_backoff: false
        }
      )
      res = client.responses.create(model: "openai/gpt-4o", input: "Hi")
      expect(res[:id]).to eq("b")
      expect(WebMock).to have_requested(:post, "https://openrouter.ai/api/v1/responses").twice
    end

    it "with api_call_log responses_attempts final persists one row for two HTTP retries" do
      rows = []
      klass = Class.new do
        define_singleton_method(:create!) { |attrs| rows << attrs }
      end
      stub_const("SavvyOpenrouter::SpecResponsesLogFinal", klass)

      stub_request(:post, "https://openrouter.ai/api/v1/responses")
        .to_return(
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { id: "a", status: "completed", usage: { output_tokens: 0 } }.to_json
          },
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: { id: "b", status: "completed", usage: { output_tokens: 1, cost: 0.002 } }.to_json
          }
        )

      client = SavvyOpenrouter::Client.new(
        api_key: "sk-test",
        responses_retries: {
          max_attempts: 3,
          base_delay_ms: 0,
          jitter_ratio: 0,
          exponential_backoff: false
        },
        api_call_log: {
          model: "SavvyOpenrouter::SpecResponsesLogFinal",
          responses_attempts: "final",
          columns: {
            "path" => "url",
            "endpoint" => "ep",
            "cost" => "cost_usd"
          }
        }
      )
      client.responses.create(model: "openai/gpt-4o-mini", input: "hello")
      expect(rows.size).to eq(1)
      expect(rows.first["ep"]).to eq("responses")
      expect(rows.first["cost_usd"]).to eq(BigDecimal("0.002"))
    end
  end
end
