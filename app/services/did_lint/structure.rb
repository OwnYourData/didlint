module DidLint
    # The context constraints (OverlayDidContextValidation) of the SOyA
    # structure, cached per DRI. A DRI addresses immutable content, so the TTL
    # only bounds how long a repository outage stays unnoticed. If a refresh
    # fails, the last copy is used; without any copy StructureUnavailable is
    # raised.
    module Structure
        TTL = 600
        TIMEOUT = 10
        @cache = {}
        @mutex = Mutex.new

        def self.context_constraints(dri)
            entry = @mutex.synchronize { @cache[dri] }
            return entry[:value] if entry && Time.now - entry[:at] < TTL
            begin
                value = fetch(dri)
            rescue StandardError => e
                return entry[:value] if entry
                raise StructureUnavailable, "SOyA structure #{dri} not available: #{e.message}"
            end
            @mutex.synchronize { @cache[dri] = { value: value, at: Time.now } }
            value
        end

        def self.fetch(dri)
            soya_repo = ENV["SOYA_REPO"] || SOYA_REPO
            response = HTTParty.get(soya_repo + "/" + dri, timeout: TIMEOUT)
            raise "HTTP #{response.code}" unless response.code == 200
            graph = response.parsed_response["@graph"]
            overlay = graph.find { |doc| doc["@type"] == "OverlayDidContextValidation" }
            raise "no OverlayDidContextValidation" if overlay.nil?
            overlay["constraints"]
        end

        def self.clear
            @mutex.synchronize { @cache.clear }
        end
    end
end
