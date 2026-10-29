require "rails_helper"

RSpec.describe "Web frontend", type: :request do
  before do
    stub_soya_structure
    stub_soya_validations
  end

  it "renders the start page without third-party tracking" do
    get "/"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("DID Linter")
    expect(response.body).not_to include("googletagmanager")
  end

  it "has no Beta label and offers a light/dark switch" do
    get "/"
    expect(response.body).not_to match(/>\s*Beta\s*</i)
    expect(response.body).to include('id="theme-toggle"')
  end

  it "links the Universal Resolver of OwnYourData from the header" do
    get "/"
    expect(response.body).to match(%r{<nav>.*<a href="https://uniresolver.ownyourdata.eu">Resolver</a>.*</nav>}m)
  end

  it "links the version from the footer instead of showing build details" do
    get "/"
    expect(response.body).to include('<a href="/version">Version</a>')
    expect(response.body).not_to include("DID Linter #{VERSION}")
  end

  it "loads no stylesheet, script or image from another host" do
    get "/"
    external = response.body.scan(/<(?:link|script|img)\b[^>]*(?:href|src)="(https?:[^"]*)"/).flatten
    expect(external).to eq([])
  end

  it "escapes values from the validated document in the result" do
    document = { "@context" => ["https://www.w3.org/ns/did/v1", "<b>probe</b>"], "id" => "did:example:123" }
    post "/validate", params: { did_document: document.to_json, commit: "Validate" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("&#39;&lt;b&gt;probe&lt;/b&gt;&#39; is not yet listed")
    expect(response.body).not_to include("<b>probe</b>")
    expect(response.body).to include(DID_REGISTRY_LINK)
  end

  it "resolves and validates a DID and shows the result right below the DID form" do
    did = "did:oyd:zQmZZbVygmbsxWXhP2BH5nW2RMNXSQA3eRqnzfkFXzH3fg1"
    stub_oydid_resolver(did)
    get "/validate", params: { did: did }
    expect(response).to have_http_status(:ok)
    body = response.body
    expect(body).to include("Conforms to W3C DID Spec v1.0")
    expect(body.index('id="did-result"')).to be < body.index('id="document"')
    expect(body.index("Conforms to W3C DID Spec v1.0")).to be < body.index('id="document"')
  end

  it "shows the result of a document check below the document form and jumps to it" do
    document = { "@context" => ["https://www.w3.org/ns/did/v1", "<b>probe</b>"], "id" => "did:example:123" }
    post "/validate", params: { did_document: document.to_json, commit: "Validate" }
    body = response.body
    expect(body).to include('action="/validate#result"')
    expect(body).not_to include('id="did-result"')
    expect(body.index('id="result"')).to be > body.index('id="document"')
  end

  it "tells the user when the SOyA structure is not available" do
    without_any_structure do
      post "/validate", params: { did_document: { "id" => "did:example:123" }.to_json, commit: "Validate" }
    end
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("The SOyA structure used for validation is not available")
  end

  describe "status of the DIF-recommended methods" do
    let(:published) { Rails.root.join("spec/fixtures/status/dif-methods.json").read }

    it "lists every method with its example DIDs, linked to a check" do
      stub_request(:get, DidLint::MethodStatus::DEFAULT_URL).to_return(status: 200, body: published)
      get "/"
      body = response.body
      expect(body).to include('<h2 id="methods">DIF-recommended methods</h2>')
      %w[did:cid did:ethr did:hedera did:webplus did:webvh did:oyd].each { |m| expect(body).to include("<code>#{m}</code>") }
      did = "did:oyd:zQmZZbVygmbsxWXhP2BH5nW2RMNXSQA3eRqnzfkFXzH3fg1"
      expect(body).to include(%(href="/validate?did=#{CGI.escape(did)}"))
      expect(body).to include('<span class="badge bad">violations</span>', '<span class="badge ok">conforms</span>')
      expect(body).to include("@context: add &#39;https://w3id.org/security/multikey/v1&#39; · result from 28 October 2026")
      expect(body.scan("result from").size).to eq(1)
      expect(body).to include("with 1 note", "The Universal Resolver has no driver for did:webplus yet")
      expect(body).to match(/Last checked \d{1,2} \w+ \d{4}, \d\d:\d\d UTC with DID Linter 1\.1\.0\./)
      expect(body.index('id="methods"')).to be > body.index("How DID Linter checks")
    end

    it "escapes what the status file contains" do
      data = JSON.parse(published)
      data["methods"][1]["dids"][0]["status"] = "violations"
      data["methods"][1]["dids"][0]["errors"] = [{ "value" => "id", "error" => "<script>x</script>" }]
      data["methods"][1]["note"] = "<img src=x>"
      stub_request(:get, DidLint::MethodStatus::DEFAULT_URL).to_return(status: 200, body: data.to_json)
      get "/"
      expect(response.body).to include("id: &lt;script&gt;x&lt;/script&gt;", "&lt;img src=x&gt;")
      expect(response.body).not_to include("<script>x</script>", "<img src=x>")
    end

    it "leaves the section out when no status is available" do
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('id="methods"')
    end
  end
end
