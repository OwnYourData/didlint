require "rails_helper"

RSpec.describe "API", type: :request do
  let(:pytest) { Rails.root.join("pytest") }
  let(:did) { "did:oyd:zQmZZbVygmbsxWXhP2BH5nW2RMNXSQA3eRqnzfkFXzH3fg1" }

  before do
    stub_soya_structure
    stub_soya_validations
  end

  it "reports the version and the pinned structure" do
    stub_soya_web_cli_version
    get "/version"
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body).to include("service" => "DID Linter", "version" => VERSION, "did-dri" => SOYA_DID_DRI)
    expect(body["oydid-gem"]).to eq(Gem.loaded_specs["oydid"].version.to_s)
  end

  it "resolves and validates a did:oyd" do
    stub_oydid_resolver(did)
    get "/api/validate/#{did}"
    expect(response).to have_http_status(:ok)
    expect(response.body).to eq(pytest.join("01_output/valid_oyd.doc").read.strip)
    expect(response.headers["X-DID-Resolved-Via"]).to eq("http")
  end

  it "returns the resolved document with the requested DID as id" do
    updated = "did:oyd:zQmSE1hzumtZ7AoK1qhHf4t5kiKsujMsJSHqoXtWrdd7K7W"
    stub_oydid_resolver(updated)
    get "/api/resolve/#{updated}"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["id"]).to eq(updated)
  end

  it "validates a posted DID document" do
    post "/api/validate", params: pytest.join("02_input/valid_oyd.json").read,
                          headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to eq(pytest.join("02_output/valid_oyd.json").read.strip)
  end

  it "answers 502 when the SOyA structure is not available" do
    stub_request(:get, "#{SOYA_REPO}/#{SOYA_DID_DRI}").to_return(status: 503)
    post "/api/validate", params: pytest.join("02_input/valid_oyd.json").read,
                          headers: { "Content-Type" => "application/json" }
    expect(response).to have_http_status(:bad_gateway)
    expect(JSON.parse(response.body)).to eq("valid" => false, "error" => "SOyA structure not available")
  end

  it "answers 404 for unknown paths" do
    get "/no/such/path"
    expect(response).to have_http_status(:not_found)
  end
end
