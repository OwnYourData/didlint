#!/usr/bin/env ruby
# encoding: utf-8

require 'json'
require 'yaml'
require 'httparty'

STATUS_COMPLIANT = "compliant"
STATUS_PARTIALLY_COMPLIANT = "partially compliant"
STATUS_NON_COMPLIANT = "non-compliant"
STATUS_NO_RESPONSE = "no response"

did_source = ENV["DID_SOURCE"] || "https://raw.githubusercontent.com/decentralized-identity/universal-resolver/main/uni-resolver-web/src/main/resources/application.yml"
did_linter = ENV["DID_LINTER"] || "https://didlint.ownyourdata.eu/api/validate/"
did_jschema_linter = ENV["DID_JSON_SCHEMA_LINTER"] || "https://didlint.ownyourdata.eu/api/validate_json-schema/" # "http://localhost:3200/api/validate_json-schema/"
did_jsonld_linter = ENV["DID_JSONLD_LINTER"] || "https://didlint.ownyourdata.eu/api/validate_jsonld/" # "http://localhost:3200/api/validate_jsonld/"
did_resolver = ENV["DID_RESOLVER"] || "https://dev.uniresolver.io/1.0/identifiers/"
http_timeout = ENV["HTTP_TIMEOUT"] || 5 rescue 5

input = YAML.load(HTTParty.get(did_source)) rescue nil
if input.nil?
    puts '{"error": "cannot load input DIDs"}'
    return
end

dids = input["uniresolver"]["drivers"].map{|e| e["testIdentifiers"]}.flatten rescue nil
if dids.nil?
    puts '{"error": "cannot parse input"}'
    return
end

retVal = {}
dids.each do |did|
    ts_start = Time.now
    did_method = did.split(":")[0..1].join(":")
    begin
        validation_response = HTTParty.get(did_linter + did, timeout: http_timeout)
        if validation_response.body.nil? || validation_response.body.empty?
            did_status = nil
        else
            did_status = validation_response.parsed_response
        end
    rescue
        did_status = nil
    end

    # JSON Schema Validation
    begin
        jschema_validation_response = HTTParty.get(did_jschema_linter + did, timeout: http_timeout)
        if jschema_validation_response.body.nil? || jschema_validation_response.body.empty?
            did_jschema_status = nil
        else
            did_jschema_status = jschema_validation_response.parsed_response
        end
    rescue
        did_jschema_status = nil
    end

    # JSON-LD Validation
    begin
        jsonld_validation_response = HTTParty.get(did_jsonld_linter + did, timeout: http_timeout)
        if jsonld_validation_response.body.nil? || jsonld_validation_response.body.empty?
            did_jsonld_status = nil
        else
            did_jsonld_status = jsonld_validation_response.parsed_response
        end
    rescue
        did_jsonld_status = nil
    end

puts "Did: " + did.to_s
puts "- SHACL: " + did_status["valid"].to_s rescue "- SHACL: null"
puts "- JSHMA: " + did_jschema_status["valid"].to_s rescue "- JSHMA: null"
puts "- JSNLD: " + did_jsonld_status["valid"].to_s rescue "- JSHMA: null"

    identifier = {}
    if did_status.nil?
        identifier[did] = {
            "error": "no response",
            "duration": Time.now - ts_start
        }
        if retVal[did_method].nil?
            retVal[did_method] = {
                "status":STATUS_NO_RESPONSE,
                "identifiers":[identifier]
            }.transform_keys(&:to_s)
        else
            retVal[did_method]["identifiers"] << identifier
            case retVal[did_method]["status"]
            when STATUS_COMPLIANT
                retVal[did_method]["status"] = STATUS_PARTIALLY_COMPLIANT
            when STATUS_PARTIALLY_COMPLIANT
            when STATUS_NON_COMPLIANT
            when STATUS_NO_RESPONSE
            end
        end
    else
        if did_status["valid"]
            identifier[did] = {
                "valid": true,
                "valid_shacl": true,
                "valid_json-schema": did_jschema_status["valid"],
                "valid_jsonld": did_jsonld_status["valid"],
                "duration": Time.now - ts_start
            }
            if retVal[did_method].nil?
                retVal[did_method] = {
                    "status":STATUS_COMPLIANT,
                    "identifiers":[identifier],
                }.transform_keys(&:to_s)
            else
                retVal[did_method]["identifiers"] << identifier
                case retVal[did_method]["status"]
                when STATUS_COMPLIANT
                when STATUS_PARTIALLY_COMPLIANT
                when STATUS_NON_COMPLIANT
                    retVal[did_method]["status"] = STATUS_PARTIALLY_COMPLIANT
                when STATUS_NO_RESPONSE
                    retVal[did_method]["status"] = STATUS_PARTIALLY_COMPLIANT
                end
            end
        else
            identifier[did] = did_status
            identifier[did]["duration"] = Time.now - ts_start
            identifier[did]["valid_json-schema"] = did_jschema_status["valid"] rescue false
            identifier[did]["valid_jsonld"] = did_jsonld_status["valid"] rescue false
            begin
                resolver_response = HTTParty.get(did_resolver + did, timeout: http_timeout).code
            rescue
                resolver_response = 500
            end
            if retVal[did_method].nil?
                if resolver_response == 200
                    # non compliant
                    retVal[did_method] = {
                        "status":STATUS_NON_COMPLIANT,
                        "identifiers":[identifier]
                    }.transform_keys(&:to_s)

                else
                    # non resolveable
                    retVal[did_method] = {
                        "status":STATUS_NO_RESPONSE,
                        "identifiers":[identifier]
                    }.transform_keys(&:to_s)
                end
            else
                if resolver_response == 200 && !did_status["error"].nil? && !did_status["error"].start_with?("Uniresolver cannot resolve")
                    # non compliant
                    if retVal[did_method].nil?
                        retVal[did_method] = {
                            "status":STATUS_NON_COMPLIANT,
                            "identifiers":[identifier]
                        }.transform_keys(&:to_s)
                    else
                        retVal[did_method]["identifiers"] << identifier
                        case retVal[did_method]["status"]
                        when STATUS_COMPLIANT
                            retVal[did_method]["status"] = STATUS_PARTIALLY_COMPLIANT
                        when STATUS_PARTIALLY_COMPLIANT
                        when STATUS_NON_COMPLIANT
                        when STATUS_NO_RESPONSE
                            retVal[did_method]["status"] = STATUS_NON_COMPLIANT
                        end
                    end
                else
                    # non resolveable
                    if retVal[did_method].nil?
                        retVal[did_method] = {
                            "status":STATUS_NON_COMPLIANT,
                            "identifiers":[identifier]
                        }.transform_keys(&:to_s)
                    else
                        retVal[did_method]["identifiers"] << identifier
                        case retVal[did_method]["status"]
                        when STATUS_COMPLIANT
                            retVal[did_method]["status"] = STATUS_PARTIALLY_COMPLIANT
                        when STATUS_PARTIALLY_COMPLIANT
                        when STATUS_NON_COMPLIANT
                        when STATUS_NO_RESPONSE
                        end
                    end

                end
            end
        end
    end
end

puts JSON.pretty_generate(retVal)