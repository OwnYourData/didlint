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
                begin
                    uniresolver_response = HTTParty.get(uniresolver_url + "/1.0/identifiers/" + did, timeout: 10)
                rescue Net::ReadTimeout
                    return nil, "time out"
                rescue
                    return nil, "invalid Uniresolver response"
                end
                ddo = JSON.parse(uniresolver_response)["didDocument"] rescue nil
                return nil, LIMIT_MESSAGE, nil if ddo.nil? && request_limit?(uniresolver_response)
                if ddo.nil?
                    err = JSON.parse(uniresolver_response)["didResolutionMetadata"]["error"] rescue nil
                    if err.nil?
                        msg = JSON.parse(uniresolver_response)["didResolutionMetadata"]["errorMessage"] rescue nil
                        if msg.nil?
                            msg = "Uniresolver cannot resolve " + did
                        end
                    else
                        msg = "Uniresolver cannot resolve " + did
                    end
                end
            end
            return ddo, msg, via
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
