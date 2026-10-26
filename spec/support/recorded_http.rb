# Replays the exchanges recorded by script/record_soya_fixtures.rb.
module RecordedHttp
  FIXTURES = Rails.root.join("spec/fixtures")

  def stub_soya_structure(dri = SOYA_DID_DRI)
    stub_request(:get, "#{SOYA_REPO}/#{dri}")
      .to_return(status: 200, body: FIXTURES.join("soya/structure_#{dri}.json").read,
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

  def stub_soya_web_cli_version
    stub_request(:get, "#{SOYA_WEB_CLI}/api/v1/version")
      .to_return(status: 200, body: { version: "test" }.to_json, headers: { "Content-Type" => "application/json" })
  end
end

RSpec.configure { |config| config.include RecordedHttp }
