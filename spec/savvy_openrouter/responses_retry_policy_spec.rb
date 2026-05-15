# frozen_string_literal: true

require "spec_helper"

RSpec.describe SavvyOpenrouter::ResponsesRetryPolicy do
  let(:policy) { described_class.new("max_attempts" => 3, "on" => { "zero_output_tokens" => true }) }

  describe "#retry_response?" do
    it "retries when zero output_tokens and failed status" do
      json = { usage: { output_tokens: 0 }, status: "failed" }
      expect(policy.retry_response?(json)).to be true
    end

    it "retries when completed with zero output_tokens" do
      json = { usage: { output_tokens: 0 }, status: "completed" }
      expect(policy.retry_response?(json)).to be true
    end

    it "does not retry when output_tokens positive" do
      json = { usage: { output_tokens: 10 }, status: "completed" }
      expect(policy.retry_response?(json)).to be false
    end

    it "is false when max_attempts is 1" do
      p1 = described_class.new({})
      json = { usage: { output_tokens: 0 }, status: "completed" }
      expect(p1.retry_response?(json)).to be false
    end
  end
end
