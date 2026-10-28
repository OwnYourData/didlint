module DidLint
    # Status of the DIF-recommended DID methods and did:oyd for the start page.
    #
    # The workflow "methods" validates the example DIDs in status/methods.json
    # daily with script/check_methods.py and publishes the result (by default
    # on GitHub Pages). This module fetches that file at most once per TTL and
    # keeps the last good copy when a refresh fails; after a failed fetch the
    # next attempt waits RETRY seconds, so a slow or missing file never delays
    # more than one page view. DIDLINT_METHOD_STATUS_URL sets another source,
    # an empty value disables the section, and so does offline mode.
    #
    # The file comes from outside the application: only known statuses are
    # kept, links only if they are https URLs, and the view escapes all text.
    module MethodStatus
        DEFAULT_URL = "https://ownyourdata.github.io/didlint/dif-methods.json"
        TTL = 3600
        RETRY = 300
        TIMEOUT = 3
        STATUSES = %w[conforms violations not_resolvable error].freeze
        @mutex = Mutex.new
        @value = nil
        @fetched_at = nil
        @tried_at = nil

        def self.url
            return nil if DidLint.offline?
            value = ENV.fetch("DIDLINT_METHOD_STATUS_URL", DEFAULT_URL).to_s.strip
            value.empty? ? nil : value
        end

        # the normalized status, or nil if none is available
        def self.current
            source = url
            return nil if source.nil?
            @mutex.synchronize do
                now = Time.now
                fresh = @fetched_at && now - @fetched_at < TTL
                waiting = @tried_at && now - @tried_at < RETRY
                unless fresh || waiting
                    @tried_at = now
                    value = fetch(source)
                    unless value.nil?
                        @value = value
                        @fetched_at = now
                    end
                end
                @value
            end
        end

        def self.clear
            @mutex.synchronize { @value = @fetched_at = @tried_at = nil }
        end

        def self.fetch(source)
            response = HTTParty.get(source, timeout: TIMEOUT, headers: { "Accept" => "application/json" })
            return nil unless response.code == 200
            normalize(JSON.parse(response.body.to_s))
        rescue StandardError => e
            Rails.logger.warn("method status from #{source} not available: #{e.class}")
            nil
        end

        def self.normalize(data)
            return nil unless data.is_a?(Hash) && data["methods"].is_a?(Array)
            generated = Time.iso8601(data["generated"].to_s) rescue nil
            return nil if generated.nil?
            methods = data["methods"].filter_map do |m|
                next unless m.is_a?(Hash) && m["method"].to_s.start_with?("did:")
                dids = Array(m["dids"]).filter_map do |d|
                    next unless d.is_a?(Hash) && d["did"].to_s.start_with?("did:") && STATUSES.include?(d["status"])
                    {
                        did: d["did"].to_s,
                        status: d["status"],
                        notes: d["notes"].to_i,
                        detail: detail(d),
                        checked: (Time.iso8601(d["checked"].to_s) rescue nil)
                    }
                end
                {
                    method: m["method"].to_s,
                    dif_recommended: m["dif_recommended"] == true,
                    link: https(m["link"]),
                    note: m["note"].to_s.presence,
                    dids: dids
                }
            end
            return nil if methods.empty?
            { generated: generated, version: data["version"].to_s.presence, methods: methods }
        end

        # the first finding or message, for one line in the list
        def self.detail(entry)
            if entry["status"] == "violations"
                first = Array(entry["errors"]).first
                return nil unless first.is_a?(Hash)
                text = [first["value"].to_s.split("/").last, first["error"]].compact.join(": ")
                more = Array(entry["errors"]).size - 1
                more > 0 ? "#{text} (+#{more} more)" : text
            else
                entry["message"].to_s.presence
            end
        end

        def self.https(value)
            value = value.to_s
            value.start_with?("https://") ? value : nil
        end
    end
end
