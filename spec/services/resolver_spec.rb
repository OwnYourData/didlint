require "rails_helper"

RSpec.describe DidLint::Resolver do
  subject(:resolver) { described_class.new }

  let(:did) { "did:oyd:zQmSE1hzumtZ7AoK1qhHf4t5kiKsujMsJSHqoXtWrdd7K7W" }
  let(:url) { "#{OYDID_RESOLVER_URL}/1.0/identifiers/#{did}" }

  context "with did:oyd" do
    it "returns the document from the OYDID resolver, with the requested DID as id" do
      stub_oydid_resolver(did)
      expect(Oydid).not_to receive(:read)
      doc, msg, via = resolver.resolve(did)
      expect(doc["id"]).to eq(did)
      expect(msg).to eq("")
      expect(via).to eq("http")
    end

    it "takes 404 as definite and does not fall back to the gem" do
      stub_request(:get, url).to_return(status: 404, body: '{"error":"not found"}')
      expect(Oydid).not_to receive(:read)
      expect(resolver.resolve(did)).to eq([nil, "did not found", nil])
    end

    it "takes a deactivated DID as definite" do
      stub_request(:get, url).to_return(
        status: 200, headers: { "Content-Type" => "application/json" },
        body: { didDocument: nil, didResolutionMetadata: {}, didDocumentMetadata: { deactivated: true } }.to_json)
      expect(Oydid).not_to receive(:read)
      expect(resolver.resolve(did)).to eq([nil, "DID deactivated", nil])
    end

    it "takes 410 as definite" do
      stub_request(:get, url).to_return(status: 410, body: '{"error":"revoked"}')
      expect(Oydid).not_to receive(:read)
      expect(resolver.resolve(did)).to eq([nil, "DID deactivated", nil])
    end

    [
      ["a server error", ->(stub) { stub.to_return(status: 503) }],
      ["an unreachable resolver", ->(stub) { stub.to_raise(Errno::ECONNREFUSED) }],
      ["a timeout", ->(stub) { stub.to_timeout }],
      ["an unparsable response", ->(stub) { stub.to_return(status: 200, body: "<html>") }]
    ].each do |label, failure|
      it "falls back to the gem on #{label}" do
        failure.call(stub_request(:get, url))
        allow(Oydid).to receive(:read).with(did, {}).and_return([{ "did" => did }, ""])
        allow(Oydid).to receive(:w3c).and_return({ "id" => did })
        doc, _, via = resolver.resolve(did)
        expect(doc).to eq({ "id" => did })
        expect(via).to eq("gem")
      end
    end
  end

  context "with other methods" do
    it "resolves through the Universal Resolver" do
      key = "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"
      stub_request(:get, "#{UNIRESOLVER_URL}/1.0/identifiers/#{key}").to_return(
        status: 200, headers: { "Content-Type" => "application/did-resolution" },
        body: { didDocument: { id: key }, didResolutionMetadata: {}, didDocumentMetadata: {} }.to_json)
      expect(resolver.resolve(key)).to eq([{ "id" => key }, "", nil])
    end

    it "reports a method the Universal Resolver does not support" do
      stub_request(:get, "#{UNIRESOLVER_URL}/1.0/identifiers/did:fake:inexistent").to_return(
        status: 501, headers: { "Content-Type" => "application/did-resolution" },
        body: { didDocument: nil, didResolutionMetadata: { error: { type: "METHOD_NOT_SUPPORTED" } } }.to_json)
      expect(resolver.resolve("did:fake:inexistent")).to eq([nil, "Uniresolver cannot resolve did:fake:inexistent", nil])
    end
  end
end
