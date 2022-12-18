module ContextHelper
    def getVerificationMethodTypes(soya_dri)
        soya_doc = HTTParty.get("https://soya.ownyourdata.eu/" + soya_dri)
        vmts = nil
        soya_doc["@graph"].each do |doc|
            if doc["@type"] == "OverlayDidContextValidation"
                vmts = doc
                break
            end
        end
        return vmts["constraints"]

        # retVal = []
        # vmt = {"type": "JsonWebKey2020", "context": "https://w3id.org/security/suites/jws-2020/v1"}.stringify_keys
        # retVal << vmt
        # vmt = {"type": "Ed25519VerificationKey2020", "context": "https://w3id.org/security/suites/ed25519-2020/v1"}.stringify_keys
        # retVal << vmt
        # return retVal
    end

    def deep_find(key, object=self, found=[])
        if object.respond_to?(:key?) && object.transform_keys(&:to_s).key?(key)
            found << object.transform_keys(&:to_s)[key]
        end
        if object.is_a? Enumerable
            found << object.collect { |*a| deep_find(key, a.last) }
        end
        found.flatten.compact.uniq
    end

    def validate_DID_context(did_document)
        violations=[]
        jld_context = did_document["@context"]
        if jld_context.is_a?(String)
            jld_context = [jld_context]
        end
        vmts = getVerificationMethodTypes(SOYA_DID_DRI)
        vmts.each do |vmt|
            key = (vmt.keys - ["context"]).first
            vals = deep_find(key, did_document)
            if vals.count > 0
                if vals.include?(vmt[key]) || vmt[key] == "*"
                    if jld_context.nil? || !jld_context.include?(vmt["context"])
                        violations << {"value":"@context", "error": "missing '" + vmt["context"].to_s + "'"}
                    end
                end
            end
        end
        return violations
    end

end
