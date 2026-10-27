module DidLint
    # The validation pipeline shared by the API and the web frontend: SOyA
    # (SHACL) validation of the document, followed by the check of the JSON-LD
    # context against the verification method types listed in the SOyA
    # structure. The result is the v1 response of /api/validate.
    class Linter
        # members whose findings an unlisted verification method type can cause
        VERIFICATION_MEMBERS = %w[verificationMethod authentication assertionMethod keyAgreement capabilityInvocation capabilityDelegation].freeze

        # dri: the SOyA structure to validate against; default is the one in
        # use (DidLint::Structure.active_dri), fixed for the lifetime of the
        # instance so that one validation never mixes two structures
        def initialize(dri: nil)
            @dri = dri
        end

        def dri
            @dri ||= DidLint::Structure.active_dri
        end

        def validate(input)
            # pre-process DID Document
            ddo = soya_prep(input.dup)

            # soya validation
            retVal = soya_validate(ddo.to_json, input.dup.to_json).transform_keys(&:to_s)

            # context validation
            # - but: skip context validation for invalid jsonld 
            context_error = retVal["errors"].first.transform_keys(&:to_s)["value"].to_s rescue ""
            if context_error != "jsonld-validation"
                context_retVal = validate_DID_context(input.dup)

                # consider JSON vs. JSON-LD representation
                # https://www.w3.org/TR/did-core/#json

                if input["@context"].nil?
                    # assume JSON representation
                    retVal["infos"] = context_retVal

                else
                    # assume JSON-LD representation
                    # https://www.w3.org/TR/did-core/#json-ld

                    # check if context is in the registered verification methods
                    soya_did_dri = dri
                    vmts = DidLint::Structure.context_constraints(soya_did_dri).map{|i| i["context"]}
                    not_standard_vmts = input["@context"] - vmts rescue []
                    not_standard_vmts.delete_if { |el| el.is_a?(Hash) && (el["@base"] || el[:"@base"]) }
                    if not_standard_vmts.count > 0
                        if retVal["infos"].nil?
                            retVal["infos"] = []
                        end
                        not_standard_vmts.each do |item|
                            el = {"message": "'" + item.to_s + "' is not yet listed as Verification Method Type in the " + DID_REGISTRY_LINK}
                            retVal["infos"] << el
                        end
                        # A verification method type the structure does not list
                        # makes SHACL reject the verification method. Only these
                        # findings are dropped; findings about any other member
                        # (controller, alsoKnownAs, service, ...) are kept.
                        if !retVal["errors"].nil? && retVal["errors"].count > 0
                            error_list = retVal["errors"].dup
                            retVal["errors"] = []
                            error_list.each do |e|
                                e_s = e.transform_keys(&:to_s)
                                member = e_s["value"].to_s.split("/").last
                                unless e_s["error"].to_s.start_with?("invalid '") && VERIFICATION_MEMBERS.include?(member)
                                    retVal["errors"] << e
                                end
                            end
                            if retVal["errors"].count == 0
                                retVal["valid"] = true
                                retVal.delete("errors")
                            end
                        end
                    else
                        # merge responses
                        if context_retVal != []
                            if retVal["errors"].nil?
                                retVal["errors"] = context_retVal
                            else
                                retVal["errors"] << context_retVal
                                retVal["errors"] = retVal["errors"].flatten
                            end
                            if !retVal["errors"].nil? && retVal["errors"].count > 0
                                retVal["valid"] = false
                            end
                        end
                    end
                end

                # post-process retVal
                if !retVal["errors"].nil? && retVal["errors"].count > 0
                    retVal["errors"].each do |e|
                        e[:value] = e[:value].to_s.split("/").last.to_s
                    end
                end
                if !retVal["infos"].nil? && retVal["infos"].count > 0
                    if retVal["infos"].first.is_a?(String)
                        retVal["infos"] = ["message": retVal["infos"].first.to_s]
                    else
                        retVal["infos"].each do |e|
                            if !e[:error].nil?
                                e[:message] = e[:error]
                                e=e.delete(:error)
                            end
                        end
                    end
                end
            end

            retVal
        end

        # structure: the SOyA structure the document is validated against
        # (default: the one of dri); it decides whether set values are lists
        def soya_prep(document, structure: nil)
            retVal = {}
            soya_did_dri = dri
            soya_repo = ENV["SOYA_REPO"] || SOYA_REPO
            retVal["@context"] = {"@version": 1.1, "did": soya_repo + "/" + soya_did_dri + "/", "@vocab": soya_repo + "/" + soya_did_dri + "/"}
            DidLint::Structure.list_attributes(structure || DidLint::Structure.document(soya_did_dri)).each do |attribute|
                retVal["@context"][attribute] = {"@container": "@list"}
            end
            document["@type"] = "Did"
            retVal["@graph"] = [document.except("@context")]

            return retVal
        end

        def soya_validate(json_input, orig_ddo)
            soya_did_dri = dri
            soya_web_cli = ENV["SOYA_WEB_CLI"] || SOYA_WEB_CLI
            soya_validation_url = soya_web_cli + "/api/v1/validate/" + soya_did_dri.to_s
            jsonld_validation_url = soya_web_cli + "/api/v1/validate/jsonld"

            # skip JSON-LD validation for now
            # at_context = JSON.parse(orig_ddo)["@context"] rescue nil
            # if !at_context.nil?
            #     timeout = false
            #     begin
            #         jld_response = HTTParty.post(jsonld_validation_url, 
            #             timeout: 10,
            #             headers: { 'Content-Type' => 'application/json' },
            #             body: orig_ddo)
            #     rescue
            #         timeout = true
            #     end
            #     if jld_response.code != 200
            #         error_message = jld_response.parsed_response["message"] rescue "invalid JSON-LD"
            #         return {"valid": false, "errors": [{"value":"jsonld-validation", "error": error_message}]}
            #     end
            # end

            # offline: SHACL in a local soya-js process against the local copy
            if DidLint.offline?
                begin
                    result = LocalValidator.new.validate(Structure.self_contained(soya_did_dri), JSON.parse(json_input))
                rescue LocalValidator::Failed => e
                    Rails.logger.warn("local SHACL validation failed: " + e.message)
                    return parse_soya_output({})
                end
                return parse_soya_output(result.to_json)
            end

            timeout = false
            begin
                response = HTTParty.post(soya_validation_url, 
                    timeout: 10,
                    headers: { 'Content-Type' => 'application/json' },
                    body: json_input)
            rescue
                timeout = true
            end
            if timeout || response.code != 200
                return parse_soya_output({})
            else
                return parse_soya_output(response.to_json)
            end

            # Command line
            # soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
            # cmd = "echo '#{json_input}' | soya validate " + soya_did_dri
            # out = nil

            # require 'open3'
            # Open3.popen3(cmd) {|stdin, stdout, stderr, wait_thr|
            #   pid = wait_thr.pid # pid of the started process.
            #   out = stdout.gets(nil)
            #   exit_status = wait_thr.value # Process::Status object returned.
            # }
            # return parse_soya_output(out)

        end

        def parse_soya_output(soya_stdout)
            # check for plain error message
            start_str = soya_stdout[0,16] rescue ""
            if start_str == "\e[31merror\e[39m:"
                return {"valid": false, "errors": [{"value":"soya-cli", "error": soya_stdout[soya_stdout.rindex("error:")+7, soya_stdout.length].strip}]}
                exit
            end

            # try to parse response
            result = JSON.parse(soya_stdout) rescue nil
            if result.nil?
                return {"valid": false, "errors": [{"value":"soya-cli", "error": "cannot validate input"}]}
            end
            if result["isValid"]
                return {"valid": true}
            end
            retVal = {"valid": false}
            result["results"].each do |r|
                msg = r["message"] rescue nil
                if msg == [] || msg.to_s == ""
                    val = r["value"] rescue nil
                    if val.nil?
                        val = r["severity"]["value"].to_s rescue nil
                    end
                    if val.to_s != ""
                        case val
                        when "http://www.w3.org/ns/shacl#Violation"
                            obj = {"value": "Verification Relationship", "error": "missing"}
                        else    
                            obj = {"value": r["value"], "error": "invalid"}
                        end
                        if retVal["errors"].nil?
                            retVal["errors"] = [obj]
                        else
                            retVal["errors"] << obj
                            retVal["errors"] = retVal["errors"].flatten
                        end
                    end
                else
                    obj = {"value": r["value"], "error": r["message"].first["value"]} rescue nil
                    if !obj.nil?
                        if retVal["errors"].nil?
                            retVal["errors"] = [obj]
                        else
                            retVal["errors"] << obj
                            retVal["errors"] = retVal["errors"].flatten
                        end
                    end
                end
            end
            return retVal
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
            soya_did_dri = dri
            violations=[]
            jld_context = did_document["@context"]
            if jld_context.is_a?(String)
                jld_context = [jld_context]
            end
            clean_context = jld_context.reject { |el| el.is_a?(Hash) && (el["@base"] || el[:"@base"]) } rescue nil
            vmts = DidLint::Structure.context_constraints(soya_did_dri)
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
end
