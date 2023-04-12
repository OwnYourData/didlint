module Api
    module V1
        class ValidationsController < ApiController
            include ApplicationHelper
            include ContextHelper

            def did
                did = params[:did].to_s
                puts "Did: " + did
                if did == ""
                    render json: {"valid": false, "error": "invalid/missing DID"},
                           status: 422
                    return
                end
                input, msg = did_resolve(did)
                if input.nil?
                    render json: {"valid": false, "error": msg},
                           status: 422
                    return
                end

                puts "Input DID Document:"
                puts input.to_json

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
                        soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
                        vmts = getVerificationMethodTypes(soya_did_dri).map{|i| i["context"]}
                        not_standard_vmts = input["@context"] - vmts rescue []
                        if not_standard_vmts.count > 0
                            if retVal["infos"].nil?
                                retVal["infos"] = []
                            end
                            not_standard_vmts.each do |item|
                                el = {"message": "'" + item.to_s + "' is not yet listed as Verification Method Type in the <a href='https://www.w3.org/TR/did-spec-registries/#verification-method-types'>DID Specification Registries</a>"}
                                retVal["infos"] << el
                            end
                            # if there are non-standard verification methods, ignore "invalid '" error messages
                            if !retVal["errors"].nil? && retVal["errors"].count > 0
                                error_list = retVal["errors"].dup
                                retVal["errors"] = []
                                error_list.each do |e|
                                    if !e.transform_keys(&:to_s)["error"].to_s.start_with?("invalid '")
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

                # response
                render json: retVal.to_json, 
                       status: 200
            end

            def document
                begin
                    if params.include?("_json")
                        input = JSON.parse(params.to_json)["_json"]
                        other = JSON.parse(params.to_json).except("_json", "validation", "format", "controller", "action", "application")
                        if other != {}
                            input += [other]
                        end
                    else
                        input = JSON.parse(params.to_json).except("validation", "format", "controller", "action", "application")
                    end
                rescue => ex
                    render json: {"valid": false, "error": "can't parse input"},
                           status: 422
                    return
                end

                puts "Input DID Document:"
                puts input.to_json

                # pre-process DID Document
                ddo = soya_prep(input.dup)

                # validation
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
                        soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
                        vmts = getVerificationMethodTypes(soya_did_dri).map{|i| i["context"]}
                        not_standard_vmts = input["@context"] - vmts rescue []
                        if not_standard_vmts.count > 0
                            if retVal["infos"].nil?
                                retVal["infos"] = []
                            end
                            not_standard_vmts.each do |item|
                                el = {"message": "'" + item.to_s + "' is not yet listed as Verification Method Type in the <a href='https://www.w3.org/TR/did-spec-registries/#verification-method-types'>DID Specification Registries</a>"}
                                retVal["infos"] << el
                            end
                            # if there are non-standard verification methods, ignore "invalid '" error messages
                            if !retVal["errors"].nil? && retVal["errors"].count > 0
                                error_list = retVal["errors"].dup
                                retVal["errors"] = []
                                error_list.each do |e|
                                    if !e.transform_keys(&:to_s)["error"].to_s.start_with?("invalid '")
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

                # response
                render json: retVal.to_json, 
                       status: 200
            end

            def resolve
                did = params[:did].to_s
                puts "Did: " + did
                if did == ""
                    render json: {"valid": false, "error": "invalid/missing DID"},
                           status: 422
                    return
                end
                input, msg = did_resolve(did)
                if input.nil?
                    render json: {"error": msg},
                           status: 422
                    return
                end

                render json: input,
                       status: 200
            end
        end
    end

end