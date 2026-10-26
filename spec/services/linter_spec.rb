require "rails_helper"

# The same fixtures and expectations as script/check_fixtures.py, offline.
RSpec.describe DidLint::Linter do
  pytest = Rails.root.join("pytest")
  known = JSON.parse(pytest.join("expectations.json").read).dig("instance", "known_failures") || {}

  before do
    stub_soya_structure
    stub_soya_validations
  end

  Dir[pytest.join("0{2,3}_input/*.json")].sort.each do |path|
    name = Pathname(path).relative_path_from(pytest).to_s

    it "returns the expected verdict for #{name}" do
      skip known[name] if known.key?(name)
      expected = File.read(path.sub("_input/", "_output/")).strip
      expect(described_class.new.validate(JSON.parse(File.read(path))).to_json).to eq(expected)
    end
  end
end
