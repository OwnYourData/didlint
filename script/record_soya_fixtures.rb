# Records the HTTP exchanges the unit tests replay: the SOyA structure, the
# soya-web-cli verdict for every fixture in pytest/ and two resolver results.
# Run after SOYA_DID_DRI changes, then review the diff of spec/fixtures/:
#
#   bundle exec rails runner script/record_soya_fixtures.rb
#
require "webmock"
include WebMock::API
WebMock.enable!
WebMock.allow_net_connect!
$recs = []
WebMock.after_request(real_requests_only: true) { |req, res| $recs << [req, res] }
root = Rails.root
out = root.join("spec/fixtures")

def save(path, req, res)
  File.write(path, JSON.pretty_generate({
    "request" => req.body.to_s,
    "status" => res.status.first,
    "content_type" => res.headers["Content-Type"],
    "response" => res.body.to_s
  }) + "\n")
end

linter = DidLint::Linter.new
docs = {}
Dir[root.join("pytest/0{2,3}_input/*.json")].sort.each do |f|
  docs[f.sub(root.join("pytest").to_s + "/", "").sub("_input/", "_").sub(".json", "")] = JSON.parse(File.read(f))
end
# documents that the request specs send in addition
resolver = DidLint::Resolver.new
%w[did:oyd:zQmZZbVygmbsxWXhP2BH5nW2RMNXSQA3eRqnzfkFXzH3fg1 did:oyd:zQmSE1hzumtZ7AoK1qhHf4t5kiKsujMsJSHqoXtWrdd7K7W].each do |did|
  $recs.clear
  doc, msg, via = resolver.resolve(did)
  raise "#{did}: #{msg}" if doc.nil?
  req, res = $recs.find { |r, _| r.uri.to_s.include?("/1.0/identifiers/") }
  File.write(out.join("resolver/#{did.split(':').last}.json"), JSON.pretty_generate({"status" => res.status.first, "content_type" => res.headers["Content-Type"], "response" => res.body.to_s}) + "\n")
  docs["resolved_" + did.split(":").last] = doc
end
docs["web_probe"] = {"@context" => ["https://www.w3.org/ns/did/v1", "<b>probe</b>"], "id" => "did:example:123"}

structure_saved = false
docs.each do |name, doc|
  $recs.clear
  linter.validate(doc)
  $recs.each do |req, res|
    if req.method == :post && req.uri.to_s.include?("/api/v1/validate/")
      save(out.join("soya/validate/#{name}.json"), req, res)
    elsif req.method == :get && !structure_saved
      dri = req.uri.path.split("/").last
      File.write(out.join("soya/structure_#{dri}.json"), res.body.to_s)
      structure_saved = true
    end
  end
end
puts "recorded #{Dir[out.join('soya/validate/*.json')].size} validations"
