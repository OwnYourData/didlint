module DidLint
    class Resolver
        # dev.uniresolver.io limits how many requests a client may send
        LIMIT_MESSAGE = "Universal Resolver request limit reached, please try again later"

        # did:oyd is resolved through the OYDID resolver over HTTP, so that DID
        # Lint validates exactly what relying parties receive. Only when the
        # resolver cannot give an answer (unreachable, timeout, 5xx, unparsable
        # response) the bundled oydid gem resolves locally. A definite answer -
        # found, not found, deactivated - is never overridden by the fallback.
        # Returns [document, message, via]; via is "http" or "gem" for did:oyd.
        def resolve(did)
            return nil, "resolving DIDs is " + DidLint::OFFLINE_MESSAGE, nil if DidLint.offline?
            uniresolver_url = ENV["UNIRESOLVER_URL"] || UNIRESOLVER_URL
            msg = ""
            via = nil
            if did.start_with?("did:oyd:")
                ddo, msg, definite = oydid_resolve_http(did)
                if definite
                    return ddo, msg, (ddo.nil? ? nil : "http")
                end
                ddo, msg = Oydid.read(did, {})
                if !ddo.nil?
                    ddo = Oydid.w3c(ddo, {})
                    via = "gem"
                end
            else
                ddo, msg, elsewhere = uniresolver_resolve(uniresolver_url, did)
                fallback = uniresolver_fallback_url
                if elsewhere && !fallback.nil? && fallback != uniresolver_url.chomp("/")
                    ddo, msg, _ = uniresolver_resolve(fallback, did)
                end
            end
            return ddo, msg, via
        end

        # Other methods go to a Universal Resolver (UNIRESOLVER_URL). When it
        # gives no answer about the DID itself - not reachable, timeout,
        # unparsable response, request limit, method not supported, a failing
        # driver (HTTP 5xx) - the DID is
        # resolved once more through UNIRESOLVER_FALLBACK_URL (empty: no
        # fallback). A definite answer, such as not found, is never overridden.
        def uniresolver_fallback_url
            value = ENV.key?("UNIRESOLVER_FALLBACK_URL") ? ENV["UNIRESOLVER_FALLBACK_URL"] : UNIRESOLVER_FALLBACK_URL
            value = value.to_s.strip.chomp("/")
            value.empty? ? nil : value
        end

        # Returns [document, message, elsewhere]; elsewhere is true when another
        # Universal Resolver may still answer.
        def uniresolver_resolve(base, did)
            begin
                response = HTTParty.get(base.chomp("/") + "/1.0/identifiers/" + did, timeout: 10)
            rescue Net::ReadTimeout, Net::OpenTimeout
                return nil, "time out", true
            rescue StandardError
                return nil, "invalid Uniresolver response", true
            end
            body = JSON.parse(response.body.to_s) rescue nil
            ddo = body["didDocument"] if body.is_a?(Hash)
            return ddo, "", false unless ddo.nil?
            return nil, LIMIT_MESSAGE, true if request_limit?(response)
            metadata = body["didResolutionMetadata"] if body.is_a?(Hash)
            metadata = {} unless metadata.is_a?(Hash)
            err = metadata["error"]
            msg = err.nil? ? metadata["errorMessage"] : nil
            msg = "Uniresolver cannot resolve " + did if msg.nil?
            elsewhere = method_not_supported?(err) || body.nil? || response.code >= 500
            return nil, msg.to_s, elsewhere
        end

        # the error of a resolution result: a string (methodNotSupported), a
        # URI ending in it, or an object with a type (METHOD_NOT_SUPPORTED)
        def method_not_supported?(err)
            type = err.is_a?(Hash) ? err["type"] : err
            type.to_s.split(/[#\/]/).last.to_s.delete("_").casecmp?("methodnotsupported")
        end

        # HTTP 429, or 403 with a message about the limit instead of a
        # resolution result
        def request_limit?(response)
            return true if response.code == 429
            return false unless response.code == 403
            body = JSON.parse(response.body.to_s) rescue nil
            body.is_a?(Hash) && !body.key?("didResolutionMetadata") && body["message"].to_s.match?(/limit|too many/i)
        end

        # Returns [document, message, definite]. definite is true when the OYDID
        # resolver answered authoritatively, false when the gem should take over.
        def oydid_resolve_http(did)
            resolver_url = ENV["OYDID_RESOLVER_URL"] || OYDID_RESOLVER_URL
            begin
                response = HTTParty.get(resolver_url + "/1.0/identifiers/" + did, timeout: 10)
            rescue StandardError
                return nil, "OYDID resolver not reachable", false
            end
            case response.code
            when 200
                body = JSON.parse(response.body.to_s) rescue nil
                return nil, "invalid OYDID resolver response", false unless body.is_a?(Hash)
                if body.key?("didDocument") || body.key?("didDocumentMetadata")
                    if body.dig("didDocumentMetadata", "deactivated") == true
                        return nil, "DID deactivated", true
                    end
                    return nil, "invalid OYDID resolver response", false unless body["didDocument"].is_a?(Hash)
                    return body["didDocument"], "", true
                end
                return body, "", true
            when 404
                return nil, "did not found", true
            when 410
                return nil, "DID deactivated", true
            else
                return nil, "OYDID resolver error " + response.code.to_s, false
            end
        end
    end
end
