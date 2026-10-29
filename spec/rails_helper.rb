require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
# the stubs use the built-in defaults, never a deployment's configuration
%w[SOYA_DID_DRI SOYA_REPO SOYA_WEB_CLI OYDID_RESOLVER_URL UNIRESOLVER_URL UNIRESOLVER_FALLBACK_URL DIDLINT_OFFLINE SOYA_STRUCTURE_DIR DIDLINT_METHOD_STATUS_URL].each { |name| ENV.delete(name) }
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "webmock/rspec"

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |file| require file }

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include ActiveSupport::Testing::TimeHelpers
  config.before { DidLint::Structure.clear }
  # the start page asks for the status of the DID methods; examples that are
  # about it stub a status of their own
  config.before do
    DidLint::MethodStatus.clear
    stub_request(:get, DidLint::MethodStatus::DEFAULT_URL).to_return(status: 404)
  end
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
