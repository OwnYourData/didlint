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

        @did = params[:did].to_s
        @did_document = JSON.parse(params[:did_document].to_s) rescue nil
        if @did_document.nil?
            @result = true
            flash.now[:warning] = "Invalid input (expecting JSON)"
            render "home"
            return
        end

        puts "Input DID Document:"
        puts @did_document.to_json

        # pre-process DID Document
        ddo = soya_prep(@did_document.dup)

        # validation
        retVal = soya_validate(ddo.to_json)

        # context validation
        context_retVal = validate_DID_context(@did_document.dup)

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
        end

        @did_document = JSON.pretty_generate(@did_document)
        render "home"
    end
end