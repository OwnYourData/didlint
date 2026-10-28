require "rails_helper"

RSpec.describe DidLint::MethodStatus do
  let(:url) { described_class::DEFAULT_URL }
  let(:published) { Rails.root.join("spec/fixtures/status/dif-methods.json").read }

  def publish(body, status: 200)
    stub_request(:get, url).to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  it "reads the published status" do
    publish(published)
    status = described_class.current
    expect(status[:version]).to eq("1.1.0")
    expect(status[:methods].map { |m| m[:method] }).to eq(%w[did:cid did:ethr did:hedera did:webplus did:webvh did:oyd])
    cid = status[:methods].first
    expect(cid[:dif_recommended]).to be(true)
    expect(cid[:dids].first).to include(status: "violations",
                                        detail: "@context: add 'https://w3id.org/security/suites/jws-2020/v1' (+1 more)")
    oyd = status[:methods].last
    expect(oyd[:dif_recommended]).to be(false)
    expect(oyd[:dids].first).to include(did: "did:oyd:zQmZZbVygmbsxWXhP2BH5nW2RMNXSQA3eRqnzfkFXzH3fg1", status: "conforms")
    expect(status[:methods][3]).to include(dids: [], note: start_with("The Universal Resolver has no driver"))
    kept = status[:methods][4][:dids].last
    expect(kept[:checked]).to be < status[:generated]
    expect(status[:methods][4][:dids].first[:checked]).to eq(status[:generated])
  end

  it "asks at most once per hour and keeps the last copy when a refresh fails" do
    publish(published)
    first = described_class.current
    described_class.current
    expect(a_request(:get, url)).to have_been_made.once
    publish("", status: 503)
    travel(described_class::TTL + 1) do
      expect(described_class.current).to eq(first)
    end
    expect(a_request(:get, url)).to have_been_made.twice
  end

  it "waits before it tries again after a failure" do
    publish("", status: 404)
    expect(described_class.current).to be_nil
    expect(described_class.current).to be_nil
    expect(a_request(:get, url)).to have_been_made.once
    publish(published)
    travel(described_class::RETRY + 1) do
      expect(described_class.current).not_to be_nil
    end
  end

  it "survives timeouts and broken files" do
    stub_request(:get, url).to_timeout
    expect(described_class.current).to be_nil
    described_class.clear
    publish("<html>")
    expect(described_class.current).to be_nil
    described_class.clear
    publish({ "methods" => [] }.to_json)
    expect(described_class.current).to be_nil
  end

  it "keeps only known statuses and https links" do
    data = JSON.parse(published)
    data["methods"][0]["link"] = "javascript:alert(1)"
    data["methods"][0]["dids"][0]["status"] = "<b>great</b>"
    publish(data.to_json)
    cid = described_class.current[:methods].first
    expect(cid[:link]).to be_nil
    expect(cid[:dids].map { |d| d[:status] }).to eq(["violations"])
  end

  it "uses DIDLINT_METHOD_STATUS_URL and is off when it is empty" do
    other = "https://status.example.org/methods.json"
    stub_request(:get, other).to_return(status: 200, body: published)
    ENV["DIDLINT_METHOD_STATUS_URL"] = other
    expect(described_class.current).not_to be_nil
    described_class.clear
    ENV["DIDLINT_METHOD_STATUS_URL"] = ""
    expect(described_class.current).to be_nil
    expect(a_request(:get, url)).not_to have_been_made
  ensure
    ENV.delete("DIDLINT_METHOD_STATUS_URL")
  end

  it "makes no request in offline mode" do
    with_offline_mode { expect(described_class.current).to be_nil }
    expect(a_request(:get, url)).not_to have_been_made
  end
end
