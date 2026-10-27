require_relative "boot"

require "rails"
require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Didlint
  class Application < Rails::Application
    config.load_defaults 8.1

    # comma separated list of host names; empty allows every host
    config.hosts = ENV["allowed_hosts"].to_s.split(",").map(&:strip).reject(&:empty?)
  end
end
