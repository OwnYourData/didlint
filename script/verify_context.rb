#!/usr/bin/env ruby
# Checks the @context of a DID document (stdin) against the context constraints
# of the SOyA structure, like the DID Linter service does (validate_DID_context in
# app/services/did_lint/linter.rb).
# usage: cat did_document.json | script/verify_context.rb [DRI]
# Without DRI the structure pinned in config/initializers/constants.rb is used.

require "json"
require "net/http"

def pinned_dri
    constants = File.read(File.join(__dir__, "..", "config", "initializers", "constants.rb"))
    constants[/^SOYA_DID_DRI\s*=\s*"([^"]+)"/, 1]
end

def context_constraints(repo, dri)
    structure = JSON.parse(Net::HTTP.get(URI("#{repo}/#{dri}")))
    overlay = structure["@graph"].find { |node| node["@type"] == "OverlayDidContextValidation" }
    abort("no OverlayDidContextValidation in #{dri}") if overlay.nil?
    overlay["constraints"]
end

def deep_find(key, object, found = [])
    if object.respond_to?(:key?) && object.transform_keys(&:to_s).key?(key)
        found << object.transform_keys(&:to_s)[key]
    end
    if object.is_a?(Enumerable)
        found << object.collect { |*a| deep_find(key, a.last) }
    end
    found.flatten.compact.uniq
end

dri = ARGV[0] || ENV["SOYA_DID_DRI"] || pinned_dri
repo = ENV["SOYA_REPO"] || "https://soya.ownyourdata.eu"
did_document = JSON.parse($stdin.read)

context = did_document["@context"]
context = [context] if context.is_a?(String)
context = context.reject { |c| c.is_a?(Hash) && (c["@base"] || c[:"@base"]) } if context.is_a?(Array)

violations = []
context_constraints(repo, dri).each do |constraint|
    key = (constraint.keys - ["context"]).first
    values = deep_find(key, did_document)
    next if values.empty?
    next unless values.include?(constraint[key]) || constraint[key] == "*"
    required = constraint["context"].to_s
    short = required.gsub("https://", "").gsub("http://", "").gsub("www.", "")
    unless context.is_a?(Array) && context.any? { |c| c.to_s.include?(short) }
        violations << { "value": "@context", "error": "add '#{required}'" }
    end
end

result = violations.empty? ? { "valid": true } : { "valid": false, "errors": violations }
puts JSON.pretty_generate(result)
