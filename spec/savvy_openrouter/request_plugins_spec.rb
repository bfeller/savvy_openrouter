# frozen_string_literal: true

require "spec_helper"
require "savvy_openrouter/request_plugins"

RSpec.describe SavvyOpenrouter::RequestPlugins do
  describe ".prepare_chat_body!" do
    it "adds response-healing for json_object chat requests" do
      body = {
        model: "openai/gpt-4o-mini",
        messages: [{ role: "user", content: "hi" }],
        response_format: { type: "json_object" }
      }
      described_class.prepare_chat_body!(body)
      expect(body[:plugins]).to eq([{ id: "response-healing" }])
    end

    it "uses pdf_engine for file-parser when messages include a PDF" do
      body = {
        model: "google/gemini-2.5-pro",
        messages: [
          {
            role: "user",
            content: [
              { type: "file", file: { filename: "a.pdf", file_data: "data:application/pdf;base64,AA==" } }
            ]
          }
        ]
      }
      described_class.prepare_chat_body!(body, pdf_engine: "native")
      expect(body[:plugins]).to eq([{ id: "file-parser", pdf: { engine: "native" } }])
    end

    it "defaults pdf engine to cloudflare-ai when pdf_engine is nil" do
      body = {
        model: "x",
        messages: [
          {
            role: "user",
            content: [{ type: "file", file: { filename: "a.pdf", file_data: "https://x.com/y.pdf" } }]
          }
        ]
      }
      described_class.prepare_chat_body!(body, pdf_engine: nil)
      expect(body[:plugins]).to eq([{ id: "file-parser", pdf: { engine: "cloudflare-ai" } }])
    end
  end
end
