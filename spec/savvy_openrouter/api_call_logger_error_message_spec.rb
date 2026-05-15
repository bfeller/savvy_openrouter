# frozen_string_literal: true

require "spec_helper"
require "savvy_openrouter/api_call_logger"

RSpec.describe SavvyOpenrouter::ApiCallLogger, ".error_message_from_response_body" do
  it "reads nested error.message with symbol keys" do
    body = { error: { message: "Failed to parse x.pdf" } }
    expect(described_class.error_message_from_response_body(body)).to eq("Failed to parse x.pdf")
  end

  it "reads string keys" do
    body = { "error" => { "message" => "No credits" } }
    expect(described_class.error_message_from_response_body(body)).to eq("No credits")
  end
end
