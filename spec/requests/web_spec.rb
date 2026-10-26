require "rails_helper"

RSpec.describe "Web frontend", type: :request do
  before do
    stub_soya_structure
    stub_soya_validations
  end

  it "renders the start page without third-party tracking" do
    get "/"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("DID Lint")
    expect(response.body).not_to include("googletagmanager")
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

  it "resolves and validates a DID" do
    did = "did:oyd:zQmZZbVygmbsxWXhP2BH5nW2RMNXSQA3eRqnzfkFXzH3fg1"
    stub_oydid_resolver(did)
    get "/validate", params: { did: did }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Conforms to W3C DID Spec v1.0")
  end

  it "tells the user when the SOyA structure is not available" do
    without_any_structure do
      post "/validate", params: { did_document: { "id" => "did:example:123" }.to_json, commit: "Validate" }
    end
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("The SOyA structure used for validation is not available")
  end
end
