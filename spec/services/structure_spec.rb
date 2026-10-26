require "rails_helper"

RSpec.describe DidLint::Structure do
  let(:dri) { SOYA_DID_DRI }

  it "loads the context constraints once per TTL" do
    stub = stub_soya_structure
    first = described_class.context_constraints(dri)
    second = described_class.context_constraints(dri)
    expect(first).to include({ "id" => "*", "context" => "https://www.w3.org/ns/did/v1" })
    expect(second).to eq(first)
    expect(stub).to have_been_requested.once
  end

  it "raises StructureUnavailable without a cached copy" do
    stub_request(:get, "#{SOYA_REPO}/#{dri}").to_return(status: 503)
    expect { described_class.context_constraints(dri) }.to raise_error(DidLint::StructureUnavailable)
  end

  it "keeps serving the last copy when a refresh fails" do
    stub_const("DidLint::Structure::TTL", 0)
    stub_soya_structure.then.to_raise(Errno::ECONNREFUSED)
    first = described_class.context_constraints(dri)
    expect(described_class.context_constraints(dri)).to eq(first)
  end
end
