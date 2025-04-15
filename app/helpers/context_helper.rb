module ContextHelper
    def getVerificationMethodTypes(soya_dri)
        soya_repo = ENV["SOYA_REPO"] || SOYA_REPO
        soya_doc = HTTParty.get(soya_repo + "/" + soya_dri)
        vmts = nil
        soya_doc["@graph"].each do |doc|
            if doc["@type"] == "OverlayDidContextValidation"
                vmts = doc
                break
            end
        end
        return vmts["constraints"]
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
        soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
        violations=[]
        jld_context = did_document["@context"]
        if jld_context.is_a?(String)
            jld_context = [jld_context]
        end
        clean_context = jld_context.reject { |el| el.is_a?(Hash) && (el["@base"] || el[:"@base"]) } rescue nil
        vmts = getVerificationMethodTypes(soya_did_dri)
        vmts.each do |vmt|
            key = (vmt.keys - ["context"]).first
            vals = deep_find(key, did_document)
            if vals.count > 0
                if vals.include?(vmt[key]) || vmt[key] == "*"
                    if clean_context.nil? || !clean_context.any? { |c| c.include?(vmt["context"].gsub("https://", "").gsub("http://", "").gsub("www.", "")) }
                        violations << {"value":"@context", "error": "add '" + vmt["context"].to_s + "'"}
                    end
                end
            end
        end
        return violations
    end

end
