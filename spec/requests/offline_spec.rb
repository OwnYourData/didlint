require "rails_helper"

# DIDLINT_OFFLINE=true: no outgoing request at all (WebMock refuses every
# connection and nothing is stubbed here).
RSpec.describe "Offline mode", type: :request do
  let(:pytest) { Rails.root.join("pytest") }
  let(:known) { JSON.parse(pytest.join("expectations.json").read).dig("instance", "known_failures") }

  around { |example| with_offline_mode { example.run } }

  it "reports the mode and the pinned structure" do
    get "/version"
    body = JSON.parse(response.body)
    expect(body).to include("mode" => "offline", "did-dri" => SOYA_DID_DRI, "did-dri-source" => "pinned")
    expect(body).not_to have_key("soya-cli_version")
  end

  it "rejects everything that has to resolve a DID" do
    did = "did:oyd:zQmZZbVygmbsxWXhP2BH5nW2RMNXSQA3eRqnzfkFXzH3fg1"
    %W[/api/validate/#{did} /api/resolve/#{did} /api/validate_jsonld/#{did} /api/validate_jschema/#{did}].each do |path|
      get path
      expect(response).to have_http_status(:service_unavailable), path
      expect(JSON.parse(response.body)["error"]).to eq("resolving DIDs is not available in offline mode")
    end
    get "/validate", params: { did: did }
    expect(response.body).to include("resolving DIDs is not available in offline mode")
  end

  it "validates posted documents like the online service" do
    skip "node or soya-js (SOYA_JS) not available" unless DidLint::LocalValidator.available?
    Dir[pytest.join("0[23]_input/*.json")].sort.each do |file|
      name = file.sub(pytest.to_s + "/", "")
      next if known.key?(name)
      post "/api/validate", params: File.read(file), headers: { "Content-Type" => "application/json" }
      expect(response.body).to eq(File.read(file.sub("_input/", "_output/")).strip), name
    end
  end
end
