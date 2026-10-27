require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
# the stubs use the built-in defaults, never a deployment's configuration
%w[SOYA_DID_DRI SOYA_REPO SOYA_WEB_CLI OYDID_RESOLVER_URL UNIRESOLVER_URL DIDLINT_OFFLINE SOYA_STRUCTURE_DIR].each { |name| ENV.delete(name) }
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |file| require file }

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.before { DidLint::Structure.clear }
  # fetched structures go to a fresh directory in every example
  config.around do |example|
    Dir.mktmpdir do |dir|
      ENV["SOYA_STRUCTURE_DIR"] = dir
      example.run
    ensure
      ENV.delete("SOYA_STRUCTURE_DIR")
    end
  end
end
