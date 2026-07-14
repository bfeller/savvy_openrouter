# frozen_string_literal: true

require "spec_helper"

# Live API: OpenRouter returns free models in ranked order per category when max_price=0;
# first_ranked_free_text_model returns that first free text model (verified 2026-07-14).
RSpec.describe "OpenRouter free model ranking", :integration do
  before do
    skip "set OPENROUTER_API_KEY to run integration tests" unless ENV["OPENROUTER_API_KEY"]
  end

  it "matches known top free models for programming and roleplay" do
    client = SavvyOpenrouter::Client.new

    prog = client.models.first_ranked_free_text_model(category: "programming")
    expect(prog).to be_a(Hash)
    expect(prog[:id]).to eq("tencent/hy3:free")
    expect(prog.dig(:pricing, :prompt).to_s.to_f).to eq(0)
    expect(prog.dig(:pricing, :completion).to_s.to_f).to eq(0)

    rp = client.models.first_ranked_free_text_model(category: "roleplay")
    expect(rp).to be_a(Hash)
    expect(rp[:id]).to eq("tencent/hy3:free")
    expect(rp.dig(:pricing, :prompt).to_s.to_f).to eq(0)
    expect(rp.dig(:pricing, :completion).to_s.to_f).to eq(0)
  end
end
