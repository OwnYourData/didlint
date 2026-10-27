# Replays the exchanges recorded by script/record_soya_fixtures.rb.
module RecordedHttp
  FIXTURES = Rails.root.join("spec/fixtures")

  def stub_soya_structure(dri = SOYA_DID_DRI)
    file = [Rails.root.join("soya/#{dri}.json"), FIXTURES.join("soya/structure_#{dri}.json")].find(&:file?)
    stub_request(:get, "#{SOYA_REPO}/#{dri}")
      .to_return(status: 200, body: file.read,
                 headers: { "Content-Type" => "application/json" })
  end

  def stub_soya_validations
    Dir[FIXTURES.join("soya/validate/*.json")].each do |file|
      recording = JSON.parse(File.read(file))
      stub_request(:post, "#{SOYA_WEB_CLI}/api/v1/validate/#{SOYA_DID_DRI}")
        .with(body: recording["request"])
        .to_return(status: recording["status"], body: recording["response"],
                   headers: { "Content-Type" => recording["content_type"] })
    end
  end

  def stub_oydid_resolver(did)
    recording = JSON.parse(FIXTURES.join("resolver/#{did.split(':').last}.json").read)
    stub_request(:get, "#{OYDID_RESOLVER_URL}/1.0/identifiers/#{did}")
      .to_return(status: recording["status"], body: recording["response"],
                 headers: { "Content-Type" => recording["content_type"] })
  end

  # the recorded soya-web-cli exchanges as [request body, response body]
  def recorded_soya_validations
    Dir[FIXTURES.join("soya/validate/*.json")].sort.map do |file|
      recording = JSON.parse(File.read(file))
      [File.basename(file, ".json"), recording["request"], recording["response"]]
    end
  end

  # SHACL results without blank node ids, for comparing two validators
  def comparable_soya_result(result)
    result = JSON.parse(result) if result.is_a?(String)
    results = result["results"].map do |r|
      [r["message"].to_a.map { |m| m["value"] }.sort, r["value"], r.dig("severity", "value")]
    end
    [result["isValid"], results.sort_by(&:to_s), result["classChecks"].to_a.size]
  end

  # neither the SOyA repository nor a local copy of the structure
  def without_any_structure(dri = SOYA_DID_DRI)
    stub_request(:get, "#{SOYA_REPO}/#{dri}").to_return(status: 503)
    Dir.mktmpdir do |empty|
      allow(DidLint::Structure).to receive(:repo_dir).and_return(Pathname(empty))
      yield
    end
  end

  # the SOyA repository as seen by `bin/rails soya:fetch`
  def stub_soya_tag(name, tag, dri)
    info = { "name" => name, "history" => [{ "tag" => tag, "dri" => dri }] }
    stub_request(:get, "#{SOYA_REPO}/#{name}:#{tag}/info")
      .to_return(status: 200, body: info.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_soya_context
    stub_request(:get, DidLint::Structure::CONTEXT_URL)
      .to_return(status: 200, body: Rails.root.join("soya", DidLint::Structure::CONTEXT_FILE).read,
                 headers: { "Content-Type" => "application/json" })
  end

  def with_offline_mode
    ENV["DIDLINT_OFFLINE"] = "true"
    yield
  ensure
    ENV.delete("DIDLINT_OFFLINE")
  end

  def stub_soya_web_cli_version
    stub_request(:get, "#{SOYA_WEB_CLI}/api/v1/version")
      .to_return(status: 200, body: { version: "test" }.to_json, headers: { "Content-Type" => "application/json" })
  end
end

RSpec.configure { |config| config.include RecordedHttp }
