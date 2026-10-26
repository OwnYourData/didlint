module DidLint
    # The SOyA structure used for validation, cached per DRI.
    #
    # Online the structure is loaded from the SOyA repository; the copy in
    # soya/ (SOYA_STRUCTURE_DIR) is the fallback when the repository cannot be
    # reached. Offline only the local copy is used. A DRI addresses immutable
    # content, so the TTL only bounds how long a repository outage stays
    # unnoticed; if a refresh fails, the last copy is used. Without any copy
    # StructureUnavailable is raised.
    module Structure
        TTL = 600
        TIMEOUT = 10
        CONTEXT_URL = "https://ns.ownyourdata.eu/ns/soya-context.json"
        CONTEXT_FILE = "soya-context.json"
        @cache = {}
        @mutex = Mutex.new

        def self.dir
            Pathname(ENV["SOYA_STRUCTURE_DIR"].presence || Rails.root.join("soya"))
        end

        # the structure as published in the SOyA repository
        def self.document(dri)
            entry = @mutex.synchronize { @cache[dri] }
            return entry[:value] if entry && (DidLint.offline? || Time.now - entry[:at] < TTL)
            value = DidLint.offline? ? local(dri) : remote_or_fallback(dri, entry)
            @mutex.synchronize { @cache[dri] = { value: value, at: Time.now } }
            value
        end

        def self.context_constraints(dri)
            overlay = document(dri)["@graph"].to_a.find { |node| node["@type"] == "OverlayDidContextValidation" }
            raise StructureUnavailable, "SOyA structure #{dri} has no OverlayDidContextValidation" if overlay.nil?
            overlay["constraints"]
        end

        # the structure with the imported SOyA context inlined (JSON-LD 1.1
        # @import: local definitions take precedence), so that soya-js can
        # validate against it without loading anything
        def self.self_contained(dri)
            structure = document(dri).deep_dup
            context = structure["@context"]
            import = context.is_a?(Hash) ? context["@import"] : nil
            return structure if import.nil?
            unless import == CONTEXT_URL
                raise StructureUnavailable, "SOyA structure #{dri} imports #{import}; only #{CONTEXT_URL} is available locally"
            end
            imported = JSON.parse(read(CONTEXT_FILE))["@context"]
            structure["@context"] = imported.merge(context.except("@import"))
            structure
        end

        def self.clear
            @mutex.synchronize { @cache.clear }
        end

        def self.remote_or_fallback(dri, entry)
            soya_repo = ENV["SOYA_REPO"] || SOYA_REPO
            response = HTTParty.get(soya_repo + "/" + dri, timeout: TIMEOUT)
            raise "HTTP #{response.code}" unless response.code == 200
            JSON.parse(response.body)
        rescue StandardError => e
            return entry[:value] if entry
            begin
                local(dri)
            rescue StructureUnavailable
                raise StructureUnavailable, "SOyA structure #{dri} not available: #{e.message}"
            end
        end

        def self.local(dri)
            JSON.parse(read("#{dri}.json"))
        end

        def self.read(name)
            path = dir.join(File.basename(name))
            raise StructureUnavailable, "no local copy of #{name} in #{dir}" unless path.file?
            path.read
        end

        private_class_method :remote_or_fallback, :local, :read
    end
end
