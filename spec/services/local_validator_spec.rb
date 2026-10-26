require "rails_helper"

# The offline validator (soya-js in a local process) must decide exactly as
# soya-web-cli: every recorded exchange is replayed through it.
RSpec.describe DidLint::LocalValidator do
  before do
    skip "node or soya-js (SOYA_JS) not available" unless described_class.available?
  end

  it "gives the recorded soya-web-cli result for every recorded request" do
    structure = with_offline_mode { DidLint::Structure.self_contained(SOYA_DID_DRI) }
    recordings = recorded_soya_validations
    expect(recordings.size).to be >= 24
    recordings.each do |name, request, response|
      local = described_class.new.validate(structure, JSON.parse(request))
      expect(comparable_soya_result(local)).to eq(comparable_soya_result(response)), name
    end
  end

  it "reports a failing validation" do
    expect { described_class.new.validate({ "@graph" => "no structure" }, {}) }
      .to raise_error(described_class::Failed)
  end
end
