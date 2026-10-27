module DidLint
    # The SOyA structure used for validation, cached per DRI.
    #
    # Which structure: the one pinned by SOYA_DID_DRI, unless a newer one was
    # fetched at runtime with `bin/rails soya:fetch` (see StructureUpdate);
    # `bin/rails soya:reset` goes back to the pinned one.
    #
    # Where from: online from the SOyA repository; otherwise, and always in
    # offline mode, from the local copies - first the fetched ones in
    # SOYA_STRUCTURE_DIR (default storage/soya), then the copy shipped in soya/.
    # A DRI addresses immutable content, so the TTL only bounds how long a
    # repository outage stays unnoticed; if a refresh fails, the last copy is
    # used. Without any copy StructureUnavailable is raised.
    module Structure
        TTL = 600
        TIMEOUT = 10
        CONTEXT_URL = "https://ns.ownyourdata.eu/ns/soya-context.json"
        CONTEXT_FILE = "soya-context.json"
        ACTIVE_FILE = "active"
        @cache = {}
        @mutex = Mutex.new

        # the copy shipped with DID Lint
        def self.repo_dir
            Rails.root.join("soya")
        end

        # structures fetched at runtime
        def self.runtime_dir
            Pathname(ENV["SOYA_STRUCTURE_DIR"].presence || Rails.root.join("storage", "soya"))
        end

        def self.pinned_dri
            ENV["SOYA_DID_DRI"].presence || SOYA_DID_DRI
        end

        # the structure in use: a fetched one if activated, else the pinned one
        def self.active_dri
            file = runtime_dir.join(ACTIVE_FILE)
            dri = file.file? ? file.read.strip : ""
            return dri if dri.present? && runtime_dir.join("#{dri}.json").file?
            pinned_dri
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

        # the structure with the imported SOyA context inlined, so that soya-js
        # can validate against it without loading anything
        def self.self_contained(dri)
            inline(document(dri), JSON.parse(read(CONTEXT_FILE)))
        end

        # JSON-LD 1.1 @import: the imported context is merged, local
        # definitions take precedence
        def self.inline(structure, soya_context)
            structure = structure.deep_dup
            context = structure["@context"]
            import = context.is_a?(Hash) ? context["@import"] : nil
            return structure if import.nil?
            raise StructureUnavailable, "the structure imports #{import}; only #{CONTEXT_URL} is supported" unless import == CONTEXT_URL
            structure["@context"] = soya_context["@context"].merge(context.except("@import"))
            structure
        end

        # stores a fetched structure and the SOyA context, then uses it
        def self.activate(dri, structure_json, context_json)
            FileUtils.mkdir_p(runtime_dir)
            write(runtime_dir.join("#{dri}.json"), structure_json)
            write(runtime_dir.join(CONTEXT_FILE), context_json)
            write(runtime_dir.join(ACTIVE_FILE), dri + "\n")
            clear
        end

        # back to the pinned structure; fetched copies stay as fallback
        def self.reset
            FileUtils.rm_f(runtime_dir.join(ACTIVE_FILE))
            clear
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
            name = File.basename(name)
            path = [runtime_dir, repo_dir].map { |dir| dir.join(name) }.find(&:file?)
            raise StructureUnavailable, "no local copy of #{name}" if path.nil?
            path.read
        end

        # write to a temporary file first, so that readers never see half a file
        def self.write(path, content)
            tmp = path.sub_ext(path.extname + ".tmp")
            File.write(tmp, content)
            File.rename(tmp, path)
        end

        private_class_method :remote_or_fallback, :local, :read, :write
    end
end
