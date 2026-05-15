# frozen_string_literal: true

require "spec_helper"
require "savvy_openrouter/patterns"

RSpec.describe SavvyOpenrouter::Patterns do
  describe ".chat_structured_requested?" do
    it "detects json_object" do
      body = { response_format: { type: "json_object" } }
      expect(described_class.chat_structured_requested?(body)).to be true
    end
  end

  describe ".extract_chat_assistant_text" do
    it "reads string content" do
      msg = { "content" => "hello" }
      expect(described_class.extract_chat_assistant_text(msg)).to eq("hello")
    end

    it "concatenates text parts" do
      msg = {
        "content" => [
          { "type" => "text", "text" => "a" },
          { "type" => "image_url", "image_url" => { "url" => "x" } },
          { "type" => "text", "text" => "b" }
        ]
      }
      expect(described_class.extract_chat_assistant_text(msg)).to eq("ab")
    end
  end

  describe ".assert_parseable_json!" do
    it "accepts fenced markdown" do
      out = described_class.assert_parseable_json!(
        "```json\n{\"x\":1}\n```",
        {}
      )
      expect(out).to eq({ "x" => 1 })
    end
  end
end
