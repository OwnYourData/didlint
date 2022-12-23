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
                @did_document = JSON.pretty_generate(retVal.first)
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
        retVal = soya_validate(ddo.to_json)

        # context validation
        context_retVal = validate_DID_context(@did_document.dup)

        # consider JSON vs. JSON-LD representation
        # https://www.w3.org/TR/did-core/#json

        if @did_document["@context"].nil?
            # assume JSON representation
            retVal["infos"] = context_retVal

        else
            # assume JSON-LD representation
            # https://www.w3.org/TR/did-core/#json-ld

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
                info_text = "Consider JSON-LD representation by adding a JSON-LD Context:<ul>"
                retVal.stringify_keys["infos"].each do |e|
                    info_text += "<li>" + e.stringify_keys["value"].to_s.split("/").last.to_s + ": " + e.stringify_keys["error"].to_s + "</li>"
                end unless retVal.stringify_keys["infos"].nil?
                info_text += "</ul>"
                flash.now[:info] = info_text
            end
        end

        @did_document = JSON.pretty_generate(@did_document) rescue nil?
        render "home"
    end
end