# frozen_string_literal: true

require "savvy_openrouter"
require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each, :integration) do
    WebMock.allow_net_connect!
  end

  config.after(:each, :integration) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
