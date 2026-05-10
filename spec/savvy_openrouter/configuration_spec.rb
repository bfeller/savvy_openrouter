# frozen_string_literal: true

require "spec_helper"

RSpec.describe SavvyOpenrouter::Configuration do
  it "merges chat defaults and fills model from default_model" do
    cfg = described_class.new(
      api_key: "k",
      default_model: "openai/gpt-4o-mini",
      defaults: { temperature: 0.2 }
    )
    out = cfg.merge_chat_body(messages: [{ role: "user", content: "x" }])
    expect(out["model"]).to eq("openai/gpt-4o-mini")
    expect(out["temperature"]).to eq(0.2)
  end

  it "merges video_defaults and prompt" do
    cfg = described_class.new(
      api_key: "k",
      default_model: "google/veo-3.1",
      video_defaults: { duration: 5, aspect_ratio: "16:9" }
    )
    out = cfg.merge_video_body(prompt: "sunset")
    expect(out["model"]).to eq("google/veo-3.1")
    expect(out["duration"]).to eq(5)
    expect(out["aspect_ratio"]).to eq("16:9")
    expect(out["prompt"]).to eq("sunset")
  end

  it "merges responses_defaults only for Responses API bodies" do
    cfg = described_class.new(
      api_key: "k",
      default_model: "openai/o4-mini",
      responses_defaults: {
        plugins: [{ "id" => "web", "max_results" => 3 }],
        max_output_tokens: 9000
      }
    )
    r = cfg.merge_responses_body(input: "What is OpenRouter?")
    expect(r["model"]).to eq("openai/o4-mini")
    expect(r["plugins"].first["id"]).to eq("web")
    expect(r["max_output_tokens"]).to eq(9000)

    chat = cfg.merge_chat_body(messages: [{ role: "user", content: "x" }])
    expect(chat).not_to have_key("plugins")
  end

  it "loads api_call_log from kwargs" do
    cfg = described_class.new(
      api_key: "k",
      api_call_log: {
        model: "OpenRouterLog",
        columns: { method: "verb", status: "code" },
        max_body_bytes: 1024
      }
    )
    expect(cfg.api_call_log["model"]).to eq("OpenRouterLog")
    expect(cfg.api_call_log["columns"]["method"]).to eq("verb")
    expect(cfg.api_call_log["max_body_bytes"]).to eq(1024)
  end

  it "clears api_call_log when false" do
    cfg = described_class.new(api_key: "k", api_call_log: false)
    expect(cfg.api_call_log).to eq({})
  end

  it "loads chat_retries from kwargs" do
    cfg = described_class.new(
      api_key: "k",
      chat_retries: { max_attempts: 3, on: { rate_limit: false } }
    )
    expect(cfg.chat_retries["max_attempts"]).to eq(3)
    expect(cfg.chat_retries["on"]["rate_limit"]).to be false
  end

  it "clears chat_retries when false" do
    cfg = described_class.new(api_key: "k", chat_retries: false)
    expect(cfg.chat_retries).to eq({})
  end
end
