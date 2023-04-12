class StaticPagesController < ApplicationController
    include ApplicationHelper
    include ContextHelper

    def home
        @result = false
        @did_document = ""
        @did = params[:did].to_s
        if @did != ""
            retVal = did_resolve(@did)
            if retVal.first.nil?
                @result = true
                flash.now[:warning] = "Error in resolving DID Document: " + retVal.last.to_s
            else
                @did_document = JSON.pretty_generate(retVal.first) rescue ""
            end
        end
    end

    def resolve
        did = params[:did].to_s
        redirect_to root_path did: did

    end

    def validate
        if params[:commit] == "Reset"
            redirect_to root_path
            return
        end

        soya_web_cli = ENV["SOYA_WEB_CLI"] || SOYA_WEB_CLI
        @did_document = JSON.parse(params[:did_document].to_s) rescue nil
        if @did_document.nil?
            @did = params[:did].to_s
            @result = true
            flash.now[:warning] = "Invalid input (expecting JSON)"
            @did_document = params[:did_document].to_s
            render "home"
            return
        else
            @did = @did_document["id"].to_s
        end

        puts "Input DID Document:"
        puts @did_document.to_json

        # pre-process DID Document
        ddo = soya_prep(@did_document.dup)

        # validation
        retVal = soya_validate(ddo.to_json, @did_document.dup.to_json).transform_keys(&:to_s)

        # context validation
        # - but: skip context validation for invalid jsonld 
        context_error = retVal["errors"].first.transform_keys(&:to_s)["value"].to_s rescue ""
        if context_error != "jsonld-validation"
            context_retVal = validate_DID_context(@did_document.dup)

            # consider JSON vs. JSON-LD representation
            # https://www.w3.org/TR/did-core/#json

            if @did_document["@context"].nil?
                # assume JSON representation
                retVal["infos"] = context_retVal

            else
                # assume JSON-LD representation
                # https://www.w3.org/TR/did-core/#json-ld

                # check if context is in the registered verification methods
                soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
                vmts = getVerificationMethodTypes(soya_did_dri).map{|i| i["context"]}
                not_standard_vmts = @did_document["@context"] - vmts rescue []
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

        valid = retVal.stringify_keys["valid"] rescue nil
        if valid.nil?
            @result = false
        else
            @result = true
            if valid
                flash.now[:success] = "Conforms to W3C DID Spec v1.0"
            else
                error_text = "Error in validating DID Document:<ul>"
                retVal.stringify_keys["errors"].each do |e|
                    error_text += "<li>" + e.stringify_keys["value"].to_s.split("/").last.to_s + ": " + e.stringify_keys["error"].to_s + "</li>"
                end unless retVal.stringify_keys["errors"].nil?
                error_text += "</ul>"
                flash.now[:danger] = error_text
            end

            if !retVal["infos"].nil? && retVal["infos"].count > 0
                if retVal["infos"].first.is_a?(String)
                    info_text = retVal["infos"].first.to_s
                else
                    error_text = false
                    retVal.stringify_keys["infos"].each do |e|
                        if e.stringify_keys["error"].to_s != ""
                            error_text = true
                        end
                    end
                    if error_text
                        info_text = "Consider JSON-LD representation by adding a JSON-LD Context:<ul>"
                        retVal.stringify_keys["infos"].each do |e|
                            info_text += "<li>" + e.stringify_keys["value"].to_s.split("/").last.to_s + ": " + e.stringify_keys["error"].to_s + "</li>"
                        end unless retVal.stringify_keys["infos"].nil?
                        info_text += "</ul>"
                    else
                        info_text = "Notes on JSON-LD Context:<ul>"
                        retVal.stringify_keys["infos"].each do |e|
                            info_text += "<li>" + e.stringify_keys["message"].to_s + "</li>"
                        end unless retVal.stringify_keys["infos"].nil?
                        info_text += "</ul>"
                    end
                end
                flash.now[:info] = info_text
            end
        end

        @did_document = JSON.pretty_generate(@did_document) rescue nil?
        render "home"
    end

    def resolve_and_validate
        @did = params[:did].to_s
        if @did != ""
            retVal = did_resolve(@did)
            if retVal.first.nil?
                @result = true
                flash.now[:warning] = "Error in resolving DID Document: " + retVal.last.to_s
                render "home"
                return
            else
                @did_document = retVal.first
            end
        else
            flash.now[:warning] = "Missing DID"
            render "home"
            return
        end

        # pre-process DID Document
        ddo = soya_prep(@did_document.dup)

        # validation
        retVal = soya_validate(ddo.to_json, @did_document.dup.to_json).transform_keys(&:to_s)

        # context validation
        # - but: skip context validation for invalid jsonld 
        context_error = retVal["errors"].first.transform_keys(&:to_s)["value"].to_s rescue ""
        if context_error != "jsonld-validation"
            context_retVal = validate_DID_context(@did_document.dup)

            # consider JSON vs. JSON-LD representation
            # https://www.w3.org/TR/did-core/#json

            if @did_document["@context"].nil?
                # assume JSON representation
                retVal["infos"] = context_retVal

            else
                # assume JSON-LD representation
                # https://www.w3.org/TR/did-core/#json-ld

                # check if context is in the registered verification methods
                soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
                vmts = getVerificationMethodTypes(soya_did_dri).map{|i| i["context"]}
                not_standard_vmts = @did_document["@context"] - vmts rescue []
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

        valid = retVal.stringify_keys["valid"] rescue nil
        if valid.nil?
            @result = false
        else
            @result = true
            if valid
                flash.now[:success] = "Conforms to W3C DID Spec v1.0"
            else
                error_text = "Error in validating DID Document:<ul>"
                retVal.stringify_keys["errors"].each do |e|
                    error_text += "<li>" + e.stringify_keys["value"].to_s.split("/").last.to_s + ": " + e.stringify_keys["error"].to_s + "</li>"
                end unless retVal.stringify_keys["errors"].nil?
                error_text += "</ul>"
                flash.now[:danger] = error_text
            end

            if !retVal["infos"].nil? && retVal["infos"].count > 0
                if retVal["infos"].first.is_a?(String)
                    info_text = retVal["infos"].first.to_s
                else
                    error_text = false
                    retVal.stringify_keys["infos"].each do |e|
                        if e.stringify_keys["error"].to_s != ""
                            error_text = true
                        end
                    end
                    if error_text
                        info_text = "Consider JSON-LD representation by adding a JSON-LD Context:<ul>"
                        retVal.stringify_keys["infos"].each do |e|
                            info_text += "<li>" + e.stringify_keys["value"].to_s.split("/").last.to_s + ": " + e.stringify_keys["error"].to_s + "</li>"
                        end unless retVal.stringify_keys["infos"].nil?
                        info_text += "</ul>"
                    else
                        info_text = "Notes on JSON-LD Context:<ul>"
                        retVal.stringify_keys["infos"].each do |e|
                            info_text += "<li>" + e.stringify_keys["message"].to_s + "</li>"
                        end unless retVal.stringify_keys["infos"].nil?
                        info_text += "</ul>"
                    end
                end
                flash.now[:info] = info_text
            end
        end

        @did_document = JSON.pretty_generate(@did_document) rescue nil?
        render "home"

    end
end