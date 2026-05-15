# frozen_string_literal: true

require "spec_helper"

RSpec.describe SavvyOpenrouter::ApiCallLogger do
  describe "#enabled?" do
    it "is true when model and columns are present" do
      log = described_class.new(
        "model" => "X",
        "columns" => { "method" => "m" }
      )
      expect(log).to be_enabled
    end

    it "is false when columns missing" do
      log = described_class.new("model" => "X")
      expect(log).not_to be_enabled
    end
  end

  describe "#record" do
    it "maps canonical keys to AR columns and creates a row" do
      rows = []
      klass = Class.new do
        define_singleton_method(:create!) { |attrs| rows << attrs }
      end
      stub_const("SavvyOpenrouter::SpecApiCallLog", klass)

      log = described_class.new(
        "model" => "SavvyOpenrouter::SpecApiCallLog",
        "columns" => {
          "method" => "http_method",
          "status" => "status_code",
          "response_body" => "payload"
        }
      )

      log.record(
        "method" => "POST",
        "path" => "https://openrouter.ai/api/v1/chat/completions",
        "status" => 401,
        "duration_ms" => 1.2,
        "request_body" => "{}",
        "response_body" => '{"error":{}}',
        "error_class" => nil,
        "error_message" => nil,
        "streaming" => false
      )

      expect(rows.size).to eq(1)
      expect(rows.first).to eq(
        "http_method" => "POST",
        "status_code" => 401,
        "payload" => '{"error":{}}'
      )
    end

    it "maps whitelisted passthrough keys from attrs to columns" do
      rows = []
      klass = Class.new do
        define_singleton_method(:create!) { |attrs| rows << attrs }
      end
      stub_const("SavvyOpenrouter::SpecApiCallLog2", klass)

      log = described_class.new(
        "model" => "SavvyOpenrouter::SpecApiCallLog2",
        "columns" => {
          "endpoint" => "ep",
          "bill_forward_event_id" => "bfe_id",
          "cost" => "cost_usd",
          "usage" => "usage_json"
        }
      )

      log.record(
        "endpoint" => "chat_completions",
        "bill_forward_event_id" => 42,
        "cost" => BigDecimal("0.01"),
        "usage" => { "completion_tokens" => 1 }
      )

      expect(rows.size).to eq(1)
      expect(rows.first["ep"]).to eq("chat_completions")
      expect(rows.first["bfe_id"]).to eq(42)
      expect(rows.first["cost_usd"]).to eq(BigDecimal("0.01"))
      expect(rows.first["usage_json"]).to include("completion_tokens")
    end
  end

  describe ".format_body_for_log" do
    it "redacts api keys and truncates" do
      long = "x" * 100_000
      out = described_class.format_body_for_log("pre sk-or-v1-ABCsecret post Bearer xyz #{long}", max_bytes: 80)
      expect(out).to include("sk-or-v1-[REDACTED]")
      expect(out).to include("Bearer [REDACTED]")
      expect(out).to include("…(truncated)")
    end
  end
end
