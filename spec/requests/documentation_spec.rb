require "rails_helper"

# Keeps swagger/v1/swagger.yaml in line with the routes and the responses, and
# README and start page in line with the pinned SOyA structure.
RSpec.describe "Documentation", type: :request do
  let(:doc) { YAML.safe_load(Rails.root.join("swagger/v1/swagger.yaml").read) }
  let(:pytest) { Rails.root.join("pytest") }

  def routed_operations
    Rails.application.routes.routes.filter_map do |route|
      path = route.path.spec.to_s.sub("(.:format)", "").sub("(/:version)", "")
      next unless path.start_with?("/api/") || path == "/version"
      verbs = route.verb.to_s.split("|").map(&:downcase)
      verbs.map { |verb| [path.gsub(/:(\w+)/, '{\1}'), verb] }
    end.flatten(1).uniq.sort
  end

  def documented_operations
    doc["paths"].flat_map { |path, operations| operations.keys.map { |verb| [path, verb] } }.sort
  end

  def validation_errors(data)
    JSON::Validator.fully_validate(doc, data, fragment: "#/components/schemas/ValidationResult")
  end

  it "documents exactly the routed API operations" do
    expect(documented_operations).to eq(routed_operations)
  end

  it "is served under /api-docs" do
    get "/api-docs/v1/swagger.yaml"
    expect(response).to have_http_status(:ok)
    expect(YAML.safe_load(response.body)["paths"].keys).to eq(doc["paths"].keys)
  end

  it "describes every expected validation result" do
    outputs = Dir[pytest.join("0[123]_output/*")].sort
    expect(outputs).not_to be_empty
    outputs.each do |file|
      expect(validation_errors(JSON.parse(File.read(file)))).to eq([]), file
    end
  end

  it "rejects results with undocumented members" do
    expect(validation_errors({ "valid" => false, "warnings" => [] })).not_to eq([])
  end

  it "describes the version response" do
    stub_soya_web_cli_version
    get "/version"
    errors = JSON::Validator.fully_validate(doc, JSON.parse(response.body), fragment: "#/components/schemas/VersionInfo")
    expect(errors).to eq([])
  end

  it "names the pinned SOyA structure in the README" do
    readme = File.read(Rails.root.join("README.md"), encoding: "UTF-8")
    expect(readme).to include("#{SOYA_REPO}/#{SOYA_DID_DRI}/yaml")
    # every structure DRI mentioned is the pinned one (DIDs are not DRIs)
    expect(readme.scan(/(?<![\w:])z[1-9A-HJ-NP-Za-km-z]{44}(?!\w)/).uniq).to eq([SOYA_DID_DRI])
  end

  it "names the Apache License 2.0 in LICENSE, NOTICE, README and Swagger" do
    expect(Rails.root.join("LICENSE").read).to start_with("\n                                 Apache License\n                           Version 2.0, January 2004")
    expect(Rails.root.join("NOTICE").read).to include("licensed under the Apache License, Version 2.0")
    expect(File.read(Rails.root.join("README.md"), encoding: "UTF-8")).to include("[Apache License 2.0](LICENSE)")
    expect(doc.dig("info", "license")).to eq("name" => "Apache 2.0", "url" => "https://www.apache.org/licenses/LICENSE-2.0")
  end

  it "links the pinned SOyA structure on the start page" do
    get "/"
    expect(response.body).to include("#{SOYA_REPO}/#{SOYA_DID_DRI}/yaml")
    expect(response.body).to include("soya validate #{SOYA_DID_DRI}")
    expect(response.body).not_to include("/Did/yaml")
  end
end
