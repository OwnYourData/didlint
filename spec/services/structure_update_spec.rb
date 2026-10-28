require "rails_helper"

RSpec.describe DidLint::StructureUpdate do
  let(:out) { StringIO.new }
  let(:update) { described_class.new(out: out) }
  let(:july) { "zEb5A6X4nSxnY2PR81Chmi6BRpr2Z71H4gThVCbdQb6pA" }
  let(:april) { "z3wmSSwhcQN4bgJHtgYqSLmdqRvv8Tnv189krACn1GtJE" }
  let(:october) { "zHdg4kgBh93YY7Yz3uUi2s5JcRKcwSgHmJ5ghcAGd1HQC" }
  let(:release_1_0) { "zGHDEn5jshXVk8haXx4BxQFX6zVyrFMP6WzeAJGVwwZvU" }

  describe "#resolve" do
    it "takes a DRI as it is" do
      expect(update.resolve(SOYA_DID_DRI)).to eq(SOYA_DID_DRI)
    end

    it "resolves a name to the version tagged current" do
      stub_soya_tag("Did", "current", july)
      expect(update.resolve("Did")).to eq(july)
      expect(update.resolve("Did:current")).to eq(july)
    end

    it "fails for an unknown tag" do
      stub_soya_tag("Did", "current", july)
      stub_request(:get, "#{SOYA_REPO}/Did:nope/info").to_return(status: 404)
      expect { update.resolve("Did:nope") }.to raise_error(described_class::Failed)
    end
  end

  describe "#run" do
    before do
      skip "node or soya-js (SOYA_JS) not available" unless DidLint::LocalValidator.available?
      stub_soya_context
    end

    it "uses a structure whose verdicts match the expectations" do
      stub_soya_tag("Did", "current", SOYA_DID_DRI)
      stub_soya_structure(SOYA_DID_DRI)
      expect(update.run("Did")).to be(true)
      expect(DidLint::Structure.active_dri).to eq(SOYA_DID_DRI)
      expect(DidLint::Structure.runtime_dir.join("#{SOYA_DID_DRI}.json")).to be_file
      expect(out.string).to include("now using #{SOYA_DID_DRI}")
    end

    it "refuses the July structure, which lets invalid embedded verification methods pass" do
      stub_soya_tag("Did", "current", july)
      stub_soya_structure(july)
      expect(update.run("Did")).to be(false)
      expect(DidLint::Structure.active_dri).to eq(SOYA_DID_DRI)
      expect(out.string).to include("FAIL  02_input/invalid_embedded_vm_keyAgreement.json  expected invalid, got valid")
      expect(out.string).to include("not switched: 21 fixture(s) differ")
    end

    it "refuses the April structure, which requires a verification relationship" do
      stub_soya_structure(april)
      expect(update.run(april)).to be(false)
      expect(out.string).to include("FAIL  02_input/valid_only_relative.json  expected valid, got invalid")
      expect(out.string).to include("not switched: 18 fixture(s) differ")
    end

    it "refuses the structure of October 2026, which lets a controller that is not a DID pass" do
      stub_soya_structure(october)
      expect(update.run(october)).to be(false)
      expect(out.string).to include("FAIL  02_input/invalid_controller_not_did.json  expected invalid, got valid")
      expect(out.string).to include("FAIL  02_input/valid_service_type_set.json  expected valid, got invalid")
      expect(out.string).to include("not switched: 14 fixture(s) differ")
    end

    it "refuses the structure of release 1.0.0, which lets two services with the same id pass" do
      stub_soya_structure(release_1_0)
      expect(update.run(release_1_0)).to be(false)
      expect(out.string).to include("FAIL  02_input/invalid_service_duplicate_id.json  expected invalid, got valid")
      expect(out.string).to include("FAIL  02_input/invalid_reference_not_did_url.json  expected invalid, got valid")
      expect(out.string).to include("not switched: 3 fixture(s) differ")
    end

    it "switches anyway with force" do
      stub_soya_structure(july)
      expect(update.run(july, force: true)).to be(true)
      expect(DidLint::Structure.active_dri).to eq(july)
      expect(out.string).to include("(forced)")
    end

    it "refuses a document that is not the structure of the DRI" do
      stub_request(:get, "#{SOYA_REPO}/#{july}")
        .to_return(status: 200, body: Rails.root.join("soya/#{SOYA_DID_DRI}.json").read)
      expect(update.run(july)).to be(false)
      expect(out.string).to include("is not a structure for this DRI")
    end

    it "reports an unreachable repository" do
      stub_request(:get, "#{SOYA_REPO}/#{july}").to_raise(Errno::ECONNREFUSED)
      expect(update.run(july)).to be(false)
      expect(DidLint::Structure.active_dri).to eq(SOYA_DID_DRI)
    end
  end
end
