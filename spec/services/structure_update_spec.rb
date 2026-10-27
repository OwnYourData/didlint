require "rails_helper"

RSpec.describe DidLint::StructureUpdate do
  let(:out) { StringIO.new }
  let(:update) { described_class.new(out: out) }
  let(:july) { "zEb5A6X4nSxnY2PR81Chmi6BRpr2Z71H4gThVCbdQb6pA" }

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

    it "refuses the July structure, which lets invalid documents pass" do
      stub_soya_tag("Did", "current", july)
      stub_soya_structure(july)
      expect(update.run("Did")).to be(false)
      expect(DidLint::Structure.active_dri).to eq(SOYA_DID_DRI)
      expect(out.string).to include("FAIL  02_input/invalid_wrongVMtype.json  expected invalid, got valid")
      expect(out.string).to include("not switched")
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
