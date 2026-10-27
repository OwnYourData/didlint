require "rails_helper"

RSpec.describe DidLint::Structure do
  let(:dri) { SOYA_DID_DRI }
  let(:unknown) { "z1111111111111111111111111111111111111111111" }

  it "loads the context constraints once per TTL" do
    stub = stub_soya_structure
    first = described_class.context_constraints(dri)
    second = described_class.context_constraints(dri)
    expect(first).to include({ "id" => "*", "context" => "https://www.w3.org/ns/did/v1" })
    expect(second).to eq(first)
    expect(stub).to have_been_requested.once
  end

  it "falls back to the local copy when the repository is not reachable" do
    stub_request(:get, "#{SOYA_REPO}/#{dri}").to_return(status: 503)
    expect(described_class.document(dri)).to eq(JSON.parse(Rails.root.join("soya/#{dri}.json").read))
  end

  it "raises StructureUnavailable without repository and local copy" do
    stub_request(:get, "#{SOYA_REPO}/#{unknown}").to_return(status: 503)
    expect { described_class.context_constraints(unknown) }.to raise_error(DidLint::StructureUnavailable)
  end

  it "keeps serving the last copy when a refresh fails" do
    stub_const("DidLint::Structure::TTL", 0)
    stub_soya_structure.then.to_raise(Errno::ECONNREFUSED)
    first = described_class.context_constraints(dri)
    expect(described_class.context_constraints(dri)).to eq(first)
  end

  it "uses only the local copy in offline mode" do
    with_offline_mode do
      expect(described_class.context_constraints(dri)).to include({ "id" => "*", "context" => "https://www.w3.org/ns/did/v1" })
      expect { described_class.document(unknown) }.to raise_error(DidLint::StructureUnavailable)
    end
    expect(a_request(:any, /.*/)).not_to have_been_made
  end

  it "inlines the imported SOyA context" do
    stub_soya_structure
    structure = described_class.self_contained(dri)
    expect(structure["@context"]).not_to have_key("@import")
    expect(structure["@context"]).to include("sh" => "http://www.w3.org/ns/shacl#", "@base" => "https://soya.ownyourdata.eu/#{dri}/")
    expect(structure["@graph"]).to eq(JSON.parse(Rails.root.join("soya/#{dri}.json").read)["@graph"])
  end

  it "keeps the local copy of the pinned structure" do
    copy = JSON.parse(Rails.root.join("soya/#{dri}.json").read)
    expect(copy["@context"]["@import"]).to eq(described_class::CONTEXT_URL)
    expect(copy["@graph"].map { |node| node["@type"] }).to include("OverlayValidation", "OverlayDidContextValidation")
    expect(JSON.parse(Rails.root.join("soya/soya-context.json").read)).to have_key("@context")
  end

  describe "structure in use" do
    let(:fetched) { "zEb5A6X4nSxnY2PR81Chmi6BRpr2Z71H4gThVCbdQb6pA" }
    let(:structure_json) { Rails.root.join("spec/fixtures/soya/structure_#{fetched}.json").read }
    let(:context_json) { Rails.root.join("soya/soya-context.json").read }

    it "is the pinned one by default" do
      expect(described_class.active_dri).to eq(SOYA_DID_DRI)
    end

    it "is a fetched one after activation, from its runtime copy" do
      described_class.activate(fetched, structure_json, context_json)
      expect(described_class.active_dri).to eq(fetched)
      with_offline_mode do
        expect(described_class.document(fetched)).to eq(JSON.parse(structure_json))
      end
    end

    it "is the pinned one again after reset" do
      described_class.activate(fetched, structure_json, context_json)
      described_class.reset
      expect(described_class.active_dri).to eq(SOYA_DID_DRI)
    end

    it "ignores an activation whose copy is missing" do
      described_class.runtime_dir.join("active").write(fetched)
      expect(described_class.active_dri).to eq(SOYA_DID_DRI)
    end
  end
end
