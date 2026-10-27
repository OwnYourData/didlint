module DidLint
    # Fetches a SOyA structure at runtime and uses it, if the fixtures in
    # pytest/ still get the verdicts recorded in pytest/expectations.json
    # (fixtures listed under planned_changes may change). The check runs
    # locally through soya-js, so it needs node and SOYA_JS, but no
    # soya-web-cli. Used by `bin/rails soya:fetch`.
    class StructureUpdate
        DRI = /\Az[1-9A-HJ-NP-Za-km-z]{40,}\z/
        TIMEOUT = 30

        class Failed < StandardError; end

        def initialize(out: $stdout, repo: ENV["SOYA_REPO"] || SOYA_REPO)
            @out = out
            @repo = repo.chomp("/")
        end

        # ref: a DRI, or a name with an optional tag (Did = Did:current)
        # returns true if the structure is in use afterwards
        def run(ref, force: false)
            dri = resolve(ref)
            say "#{ref} is #{dri}"
            structure_json = get("#{@repo}/#{dri}")
            structure = JSON.parse(structure_json)
            check_structure!(dri, structure)
            context_json = get(Structure::CONTEXT_URL)
            mismatches = check_fixtures(dri, structure, Structure.inline(structure, JSON.parse(context_json)))
            if mismatches.any? && !force
                say "not switched: #{mismatches.size} fixture(s) differ from pytest/expectations.json (FORCE=1 switches anyway)"
                return false
            end
            Structure.activate(dri, structure_json, context_json)
            say "now using #{dri}" + (mismatches.any? ? " (forced)" : "")
            true
        rescue Failed, StructureUnavailable, LocalValidator::Failed, JSON::ParserError => e
            say "not switched: #{e.message}"
            false
        end

        def resolve(ref)
            ref = ref.to_s.strip
            return ref if ref.match?(DRI)
            name, tag = ref.split(":", 2)
            tag = tag.presence || "current"
            raise Failed, "invalid structure reference '#{ref}'" if name.blank?
            info = JSON.parse(get("#{@repo}/#{name}:#{tag}/info"))
            entry = info["history"].to_a.find { |h| h["tag"] == tag }
            raise Failed, "#{name} has no version tagged '#{tag}'" if entry.nil? || entry["dri"].to_s !~ DRI
            entry["dri"]
        end

        # [name, expected, got] for every fixture with an unexpected verdict
        def check_fixtures(dri, structure, self_contained)
            raise Failed, "node or soya-js (SOYA_JS) not available" unless LocalValidator.available?
            expectations = JSON.parse(Rails.root.join("pytest/expectations.json").read)["structure"]
            planned = expectations.dig("planned_changes", "become_valid").to_a
            linter = Linter.new(dri: dri)
            validator = LocalValidator.new
            mismatches = []
            expectations["valid"].sort.each do |name, expected|
                document = JSON.parse(Rails.root.join("pytest", name).read)
                got = validator.validate(self_contained, linter.soya_prep(document, structure: structure))["isValid"]
                if got == expected
                    say "PASS  #{name}  #{verdict(got)}"
                elsif planned.include?(name)
                    say "PASS  #{name}  #{verdict(got)} (planned change)"
                else
                    say "FAIL  #{name}  expected #{verdict(expected)}, got #{verdict(got)}"
                    mismatches << [name, expected, got]
                end
            end
            mismatches
        end

        private

        def check_structure!(dri, structure)
            base = structure.dig("@context", "@base").to_s
            raise Failed, "#{dri} is not a structure for this DRI (@base #{base})" unless base.end_with?("/#{dri}/")
            overlay = structure["@graph"].to_a.find { |node| node["@type"] == "OverlayDidContextValidation" }
            raise Failed, "#{dri} has no OverlayDidContextValidation" if overlay.nil?
        end

        def get(url)
            response = HTTParty.get(url, timeout: TIMEOUT)
            raise Failed, "#{url}: HTTP #{response.code}" unless response.code == 200
            response.body
        rescue Failed
            raise
        rescue StandardError => e
            raise Failed, "#{url}: #{e.message}"
        end

        def verdict(valid)
            valid ? "valid" : "invalid"
        end

        def say(line)
            @out.puts(line)
        end
    end
end
