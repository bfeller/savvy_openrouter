# frozen_string_literal: true

require "spec_helper"

RSpec.describe SavvyOpenrouter::Resources::Videos do
  let(:client) { SavvyOpenrouter::Client.new(api_key: "sk-test") }
  let(:videos) { client.videos }

  describe "#create" do
    it "accepts HTTP 202 from POST /videos" do
      stub_request(:post, "https://openrouter.ai/api/v1/videos")
        .with(body: hash_including("model" => "google/veo-3.1", "prompt" => "wave"))
        .to_return(
          status: 202,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "job-1",
            polling_url: "/api/v1/videos/job-1",
            status: "pending"
          }.to_json
        )

      res = videos.create(model: "google/veo-3.1", prompt: "wave")
      expect(res[:status]).to eq("pending")
      expect(res[:id]).to eq("job-1")
    end
  end

  describe "#poll_until" do
    it "returns when status becomes terminal" do
      states = [
        { status: "in_progress", id: "job-1", polling_url: "/x" },
        { status: "completed", id: "job-1", polling_url: "/x" }
      ]
      allow(videos).to receive(:get).and_return(*states)
      allow(Kernel).to receive(:sleep)

      res = videos.poll_until("job-1", interval: 0.01, timeout: 30)
      expect(res[:status]).to eq("completed")
    end
  end
end
