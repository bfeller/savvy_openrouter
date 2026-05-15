# frozen_string_literal: true

require_relative "lib/savvy_openrouter/version"

Gem::Specification.new do |spec|
  spec.name = "savvy_openrouter"
  spec.version = SavvyOpenrouter::VERSION
  spec.authors = ["Bryan Feller"]
  spec.email = ["brizzlefeller@gmail.com"]

  spec.summary = "Ruby client for the OpenRouter unified AI API."
  spec.description = [
    "OpenRouter Ruby client: chat (streaming SSE), configurable retries for non-streaming completions,",
    "optional DB-backed API call logging, Responses API defaults, models listing with filters and free-tier hints,",
    "embeddings, rerank, audio, video, OAuth, API keys, guardrails, workspaces, and related REST endpoints."
  ].join(" ")
  spec.homepage = "https://github.com/bfeller/savvy_openrouter"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.end_with?(".gem") ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 2.0", "< 4"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
  spec.add_development_dependency "webmock", "~> 3.23"

  spec.metadata["rubygems_mfa_required"] = "true"
end
