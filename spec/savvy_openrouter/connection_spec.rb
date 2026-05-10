# frozen_string_literal: true

require "spec_helper"

RSpec.describe SavvyOpenrouter::Connection do
  let(:config) { SavvyOpenrouter::Configuration.new(api_key: "sk-test") }
  let(:conn) { described_class.new(config) }

  describe "#post" do
    it "raises AuthenticationError on 401 JSON body" do
      stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
        .to_return(
          status: 401,
          headers: { "Content-Type" => "application/json" },
          body: { error: { code: 401, message: "Missing Authentication header" } }.to_json
        )

      expect do
        conn.post("/chat/completions", body: { model: "x", messages: [] })
      end.to raise_error(SavvyOpenrouter::AuthenticationError, /Missing Authentication/)
    end

    context "with api_call_log configured" do
      let(:log_storage) { [] }

      before do
        storage = log_storage
        klass = Class.new do
          define_singleton_method(:create!) { |attrs| storage << attrs }
        end
        stub_const("SavvyOpenrouter::SpecApiCallLogRow", klass)
      end

      let(:config) do
        SavvyOpenrouter::Configuration.new(
          api_key: "sk-test",
          api_call_log: {
            model: "SavvyOpenrouter::SpecApiCallLogRow",
            columns: {
              "method" => "verb",
              "path" => "url",
              "status" => "code",
              "duration_ms" => "ms",
              "request_body" => "req",
              "response_body" => "resp",
              "streaming" => "sse"
            }
          }
        )
      end

      let(:conn) { described_class.new(config) }

      it "persists one row per HTTP exchange with mapped columns" do
        stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
          .to_return(
            status: 401,
            headers: { "Content-Type" => "application/json" },
            body: { error: { message: "bad" } }.to_json
          )

        expect do
          conn.post("/chat/completions", body: { model: "x", messages: [] })
        end.to raise_error(SavvyOpenrouter::AuthenticationError)

        expect(log_storage.size).to eq(1)
        row = log_storage.first
        expect(row["verb"]).to eq("POST")
        expect(row["url"]).to include("chat/completions")
        expect(row["code"]).to eq(401)
        expect(row["sse"]).to be false
        expect(row["req"]).to include("model")
        expect(row["resp"]).to include("error")
      end
    end
  end

  describe "#get_raw" do
    it "returns binary body for octet-stream success" do
      stub_request(:get, %r{/videos/job-1/content})
        .to_return(status: 200, body: "VIDEOBYTES", headers: { "Content-Type" => "application/octet-stream" })

      bytes = conn.get_raw("/videos/job-1/content", params: { index: 0 })
      expect(bytes).to eq("VIDEOBYTES")
    end

    it "raises BadGatewayError on 502 JSON" do
      stub_request(:get, %r{/videos/job-1/content})
        .to_return(
          status: 502,
          headers: { "Content-Type" => "application/json" },
          body: { error: { code: 502, message: "upstream failed" } }.to_json
        )

      expect do
        conn.get_raw("/videos/job-1/content")
      end.to raise_error(SavvyOpenrouter::BadGatewayError)
    end
  end
end
