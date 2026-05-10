# frozen_string_literal: true

require "spec_helper"

RSpec.describe SavvyOpenrouter::CompletionRetryPolicy do
  describe "#retry_response?" do
    it "is false when max_attempts is 1" do
      p = described_class.new("max_attempts" => 1)
      res = { choices: [{ message: { content: "" } }], usage: { completion_tokens: 0 } }
      expect(p.retry_response?(res)).to be false
    end

    it "retries when completion_tokens is zero" do
      p = described_class.new("max_attempts" => 3)
      res = { choices: [{ message: { content: "x" } }], usage: { completion_tokens: 0 } }
      expect(p.retry_response?(res)).to be true
    end

    it "still retries for zero completion_tokens when tool_calls present (tokens may be misreported)" do
      p = described_class.new("max_attempts" => 3)
      res = {
        choices: [{ message: { content: "", tool_calls: [{ id: "1" }] } }],
        usage: { completion_tokens: 0 }
      }
      expect(p.retry_response?(res)).to be true
    end

    it "does not retry empty content when disabled" do
      p = described_class.new(
        "max_attempts" => 3,
        "on" => { "empty_assistant_content" => false, "zero_completion_tokens" => false }
      )
      res = { choices: [{ message: { content: "" } }], usage: { completion_tokens: 1 } }
      expect(p.retry_response?(res)).to be false
    end
  end

  describe "#retry_http_error?" do
    it "retries rate limits when enabled" do
      p = described_class.new("max_attempts" => 3)
      err = SavvyOpenrouter::RateLimitError.new("slow", status_code: 429)
      expect(p.retry_http_error?(err)).to be true
    end

    it "does not retry when disabled" do
      p = described_class.new("max_attempts" => 1)
      err = SavvyOpenrouter::RateLimitError.new("slow", status_code: 429)
      expect(p.retry_http_error?(err)).to be false
    end
  end
end
