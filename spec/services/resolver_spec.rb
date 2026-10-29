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
    let(:key) { "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK" }
    let(:primary) { "#{UNIRESOLVER_URL}/1.0/identifiers/#{key}" }
    let(:fallback) { "#{UNIRESOLVER_FALLBACK_URL}/1.0/identifiers/#{key}" }
    let(:found) do
      { status: 200, headers: { "Content-Type" => "application/did-resolution" },
        body: { didDocument: { id: key }, didResolutionMetadata: {}, didDocumentMetadata: {} }.to_json }
    end
    let(:not_supported) do
      { status: 501, headers: { "Content-Type" => "application/did-resolution" },
        body: { didDocument: nil, didResolutionMetadata: { error: { type: "METHOD_NOT_SUPPORTED" } } }.to_json }
    end
    let(:limit) do
      { status: 403, headers: { "Content-Type" => "application/json" },
        body: { status: 403, error: "Forbidden", message: "Too many Universal Resolver requests. Only 10 requests are allowed per 1800 seconds." }.to_json }
    end

    it "resolves through the Universal Resolver" do
      stub_request(:get, primary).to_return(found)
      expect(resolver.resolve(key)).to eq([{ "id" => key }, "", nil])
      expect(a_request(:get, fallback)).not_to have_been_made
    end

    it "asks the fallback when the first resolver does not support the method" do
      stub_request(:get, primary).to_return(not_supported)
      stub_request(:get, fallback).to_return(found)
      expect(resolver.resolve(key)).to eq([{ "id" => key }, "", nil])
    end

    it "asks the fallback when the first resolver is not reachable or answers with an error page" do
      stub_request(:get, primary).to_timeout.then.to_return(status: 502, body: "<html>Bad Gateway</html>")
      stub_request(:get, fallback).to_return(found)
      expect(resolver.resolve(key)).to eq([{ "id" => key }, "", nil])
      expect(resolver.resolve(key)).to eq([{ "id" => key }, "", nil])
      expect(a_request(:get, fallback)).to have_been_made.twice
    end

    it "asks the fallback when a driver of the first resolver fails" do
      stub_request(:get, primary).to_return(
        status: 500, headers: { "Content-Type" => "application/did-resolution" },
        body: { didDocument: nil, didResolutionMetadata: { error: { type: "INTERNAL_ERROR" } } }.to_json)
      stub_request(:get, fallback).to_return(found)
      expect(resolver.resolve(key)).to eq([{ "id" => key }, "", nil])
    end

    it "keeps a definite answer of the first resolver" do
      stub_request(:get, primary).to_return(
        status: 404, headers: { "Content-Type" => "application/did-resolution" },
        body: { didDocument: nil, didResolutionMetadata: { error: { type: "NOT_FOUND" } } }.to_json)
      expect(resolver.resolve(key)).to eq([nil, "Uniresolver cannot resolve #{key}", nil])
      expect(a_request(:get, fallback)).not_to have_been_made
    end

    it "makes no second request when the fallback is switched off" do
      ENV["UNIRESOLVER_FALLBACK_URL"] = ""
      stub_request(:get, primary).to_return(not_supported)
      expect(resolver.resolve(key)).to eq([nil, "Uniresolver cannot resolve #{key}", nil])
      expect(a_request(:get, fallback)).not_to have_been_made
    ensure
      ENV.delete("UNIRESOLVER_FALLBACK_URL")
    end

    it "says so when the Universal Resolver's request limit is reached" do
      stub_request(:get, primary).to_return(limit, { status: 429, body: "" },
        { status: 403, headers: { "Content-Type" => "application/json" }, body: { status: 403, error: "Forbidden" }.to_json })
      stub_request(:get, fallback).to_return(limit)
      expect(resolver.resolve(key)).to eq([nil, "Universal Resolver request limit reached, please try again later", nil])
      expect(resolver.resolve(key)).to eq([nil, "Universal Resolver request limit reached, please try again later", nil])
      expect(resolver.resolve(key)).to eq([nil, "Uniresolver cannot resolve #{key}", nil])
    end

    it "reports a method no Universal Resolver supports" do
      stub_request(:get, "#{UNIRESOLVER_URL}/1.0/identifiers/did:fake:inexistent").to_return(not_supported)
      stub_request(:get, "#{UNIRESOLVER_FALLBACK_URL}/1.0/identifiers/did:fake:inexistent").to_return(not_supported)
      expect(resolver.resolve("did:fake:inexistent")).to eq([nil, "Uniresolver cannot resolve did:fake:inexistent", nil])
    end
  end
end
