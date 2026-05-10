# frozen_string_literal: true

require "spec_helper"

# Live API: OpenRouter returns models in ranked order per category; "first free with zero pricing"
# matches curated top free picks when using output_modalities=text (verified 2026-05-09).
RSpec.describe "OpenRouter free model ranking", :integration do
  before do
    skip "set OPENROUTER_API_KEY to run integration tests" unless ENV["OPENROUTER_API_KEY"]
  end

  it "matches known top free models for programming and roleplay" do
    client = SavvyOpenrouter::Client.new

    prog = client.models.first_ranked_free_text_model(category: "programming")
    expect(prog).to be_a(Hash)
    expect(prog[:id]).to eq("nvidia/nemotron-3-super-120b-a12b:free")

    rp = client.models.first_ranked_free_text_model(category: "roleplay")
    expect(rp).to be_a(Hash)
    expect(rp[:id]).to eq("openrouter/owl-alpha")
  end
end
