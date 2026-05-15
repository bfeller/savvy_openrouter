# frozen_string_literal: true

require "spec_helper"

RSpec.describe SavvyOpenrouter::Resources::Chat do
  let(:client) { SavvyOpenrouter::Client.new(api_key: "sk-test") }
  let(:chat) { client.chat }

  describe "#completions_stream" do
    it "parses SSE data payloads from streamed chunks" do
      sse = <<~SSE
        data: {"choices":[{"delta":{"content":"Hi"}}]}

        data: [DONE]

      SSE

      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(status: 200, body: sse, headers: { "Content-Type" => "text/event-stream" })

      payloads = []
      chat.completions_stream(messages: [{ role: "user", content: "hello" }]) do |data|
        payloads << data
      end

      expect(payloads.size).to eq(1)
      parsed = JSON.parse(payloads.first)
      expect(parsed["choices"][0]["delta"]["content"]).to eq("Hi")
    end

    it "returns an Enumerator when no block given" do
      sse = "data: {\"x\":1}\n\n"
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(status: 200, body: sse)

      enum = chat.completions_stream(messages: [{ role: "user", content: "hello" }])
      expect(enum).to be_a(Enumerator)
      expect(JSON.parse(enum.first)).to eq({ "x" => 1 })
    end
  end

  describe "#completions" do
    it "retries on zero completion_tokens when chat_retries is configured" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              choices: [{ message: { role: "assistant", content: "" } }],
              usage: { completion_tokens: 0, prompt_tokens: 1, total_tokens: 1 }
            }.to_json
          },
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              choices: [{ message: { role: "assistant", content: "hi" } }],
              usage: { completion_tokens: 1, prompt_tokens: 1, total_tokens: 2 }
            }.to_json
          }
        )

      client = SavvyOpenrouter::Client.new(
        api_key: "sk-test",
        chat_retries: {
          max_attempts: 3,
          base_delay_ms: 0,
          jitter_ratio: 0,
          exponential_backoff: false
        }
      )
      res = client.chat.completions(messages: [{ role: "user", content: "hello" }])
      expect(res[:choices].first[:message][:content]).to eq("hi")
      expect(WebMock).to have_requested(:post, "https://openrouter.ai/api/v1/chat/completions").twice
    end

    it "does not retry without chat_retries" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              choices: [{ message: { role: "assistant", content: "" } }],
              usage: { completion_tokens: 0, prompt_tokens: 1, total_tokens: 1 }
            }.to_json
          },
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              choices: [{ message: { role: "assistant", content: "hi" } }],
              usage: { completion_tokens: 1, prompt_tokens: 1, total_tokens: 2 }
            }.to_json
          }
        )

      res = SavvyOpenrouter::Client.new(api_key: "sk-test").chat.completions(
        messages: [{ role: "user", content: "hello" }]
      )
      expect(res[:choices].first[:message][:content]).to eq("")
      expect(WebMock).to have_requested(:post, "https://openrouter.ai/api/v1/chat/completions").once
    end

    it "retries on 429 then succeeds" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(
          {
            status: 429,
            headers: { "Content-Type" => "application/json" },
            body: { error: { message: "rate limit" } }.to_json
          },
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              choices: [{ message: { content: "ok" } }],
              usage: { completion_tokens: 1 }
            }.to_json
          }
        )

      client = SavvyOpenrouter::Client.new(
        api_key: "sk-test",
        chat_retries: {
          max_attempts: 3,
          base_delay_ms: 0,
          jitter_ratio: 0,
          exponential_backoff: false
        }
      )
      res = client.chat.completions(messages: [{ role: "user", content: "hello" }])
      expect(res[:choices].first[:message][:content]).to eq("ok")
      expect(WebMock).to have_requested(:post, "https://openrouter.ai/api/v1/chat/completions").twice
    end

    it "with api_call_log chat_attempts final persists one row for two HTTP retries" do
      rows = []
      klass = Class.new do
        define_singleton_method(:create!) { |attrs| rows << attrs }
      end
      stub_const("SavvyOpenrouter::SpecChatLogFinal", klass)

      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              choices: [{ message: { role: "assistant", content: "" } }],
              usage: { completion_tokens: 0, prompt_tokens: 1, total_tokens: 1 }
            }.to_json
          },
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              choices: [{ message: { role: "assistant", content: "hi" } }],
              usage: { completion_tokens: 1, prompt_tokens: 1, total_tokens: 2, cost: 0.001 }
            }.to_json
          }
        )

      client = SavvyOpenrouter::Client.new(
        api_key: "sk-test",
        chat_retries: {
          max_attempts: 3,
          base_delay_ms: 0,
          jitter_ratio: 0,
          exponential_backoff: false
        },
        api_call_log: {
          model: "SavvyOpenrouter::SpecChatLogFinal",
          chat_attempts: "final",
          columns: {
            "path" => "url",
            "endpoint" => "ep",
            "cost" => "cost_usd"
          }
        }
      )
      res = client.chat.completions(messages: [{ role: "user", content: "hello" }], model: "openai/gpt-4o-mini")
      expect(res[:choices].first[:message][:content]).to eq("hi")
      expect(WebMock).to have_requested(:post, "https://openrouter.ai/api/v1/chat/completions").twice
      expect(rows.size).to eq(1)
      expect(rows.first["ep"]).to eq("chat_completions")
      expect(rows.first["cost_usd"]).to eq(BigDecimal("0.001"))
    end

    it "with api_call_log chat_attempts all persists one row per HTTP attempt" do
      rows = []
      klass = Class.new do
        define_singleton_method(:create!) { |attrs| rows << attrs }
      end
      stub_const("SavvyOpenrouter::SpecChatLogAll", klass)

      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              choices: [{ message: { role: "assistant", content: "" } }],
              usage: { completion_tokens: 0, prompt_tokens: 1, total_tokens: 1 }
            }.to_json
          },
          {
            status: 200,
            headers: { "Content-Type" => "application/json" },
            body: {
              choices: [{ message: { role: "assistant", content: "hi" } }],
              usage: { completion_tokens: 1, prompt_tokens: 1, total_tokens: 2 }
            }.to_json
          }
        )

      client = SavvyOpenrouter::Client.new(
        api_key: "sk-test",
        chat_retries: {
          max_attempts: 3,
          base_delay_ms: 0,
          jitter_ratio: 0,
          exponential_backoff: false
        },
        api_call_log: {
          model: "SavvyOpenrouter::SpecChatLogAll",
          chat_attempts: "all",
          columns: {
            "path" => "url",
            "endpoint" => "ep"
          }
        }
      )
      client.chat.completions(messages: [{ role: "user", content: "hello" }])
      expect(rows.size).to eq(2)
    end
  end
end
