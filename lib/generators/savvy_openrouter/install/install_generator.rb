# frozen_string_literal: true

require "rails/generators/base"

module SavvyOpenrouter
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates config/savvy_openrouter.yml for OpenRouter defaults"

      def copy_config
        copy_file "savvy_openrouter.yml", "config/savvy_openrouter.yml"
      end
    end
  end
end
