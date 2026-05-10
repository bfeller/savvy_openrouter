# frozen_string_literal: true

require "spec_helper"

FREE_INTEGRATION_MODEL = "inclusionai/ring-2.6-1t:free"

# Set OPENROUTER_API_KEY to run (e.g. export OPENROUTER_API_KEY=$(cat temp_openrouter_key.txt))
RSpec.describe "OpenRouter integration smoke", :integration do
  before do
    skip "set OPENROUTER_API_KEY to run integration smoke tests" unless ENV["OPENROUTER_API_KEY"]
  end

  it "lists models" do
    client = SavvyOpenrouter::Client.new
    res = client.models.list
    expect(res).to be_a(Hash)
    data = res[:data] || res["data"]
    expect(data).to be_an(Array)
  end

  it "runs a free chat completion" do
    client = SavvyOpenrouter::Client.new
    res = client.chat.completions(
      model: FREE_INTEGRATION_MODEL,
      messages: [{ role: "user", content: "Say only: ok" }]
    )
    expect(res).to be_a(Hash)
    expect(res[:choices]).to be_an(Array)
    expect(res[:choices].first).to be_a(Hash)
  end
end
