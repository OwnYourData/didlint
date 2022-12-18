#!/usr/bin/env ruby
# encoding: utf-8

require 'httparty'
SOYA_DID_DRI = "zQmeCh8bqJWLGYfFz2evRY7MT6QjeSZDyK64h1EdnnYbaGg"
did_document = JSON.parse($stdin.read)

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
if violations.length == 0
	retVal = {"valid": true}
else
	retVal = {"valid": false, "errors": violations}
end

puts JSON.pretty_generate(retVal)
