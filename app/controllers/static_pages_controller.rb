require "cgi"

class StaticPagesController < ApplicationController
    # @source tells the view where to show the result: right below the DID
    # form (:did) or below the document form (:document)

    rescue_from DidLint::StructureUnavailable do
        @result = true
        @source = action_name == "validate" ? :document : :did
        flash.now[:warning] = "The SOyA structure used for validation is not available, please try again later"
        @did_document = JSON.pretty_generate(@did_document) if @did_document.is_a?(Hash) || @did_document.is_a?(Array)
        render "home"
    end

    def home
        @result = false
        @source = :did
        @did_document = ""
        @did = params[:did].to_s
        if @did != ""
            retVal = resolve_did(@did)
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

        @source = :document
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

        retVal = linter.validate(@did_document)
        flash_validation(retVal)

        @did_document = JSON.pretty_generate(@did_document) rescue nil?
        render "home"
    end

    def resolve_and_validate
        @source = :did
        @did = params[:did].to_s
        if @did != ""
            retVal = resolve_did(@did)
            if retVal.first.nil?
                @result = true
                flash.now[:warning] = "Error in resolving DID Document: " + retVal.last.to_s
                render "home"
                return
            else
                @did_document = retVal.first
            end
        else
            @result = true
            flash.now[:warning] = "Missing DID"
            render "home"
            return
        end

        retVal = linter.validate(@did_document)
        flash_validation(retVal)

        @did_document = JSON.pretty_generate(@did_document) rescue nil?
        render "home"

    end


    private

    # builds the flash messages of the web frontend from a v1 validation result
    def flash_validation(retVal)
            valid = retVal.stringify_keys["valid"] rescue nil
            if valid.nil?
                @result = false
            else
                @result = true
                if valid
                    flash.now[:success] = "Conforms to W3C DID Spec v1.0"
                else
                    entries = (retVal.stringify_keys["errors"] || []).map do |e|
                        e = e.stringify_keys
                        flash_escape(e["value"].to_s.split("/").last.to_s + ": " + e["error"].to_s)
                    end
                    flash.now[:danger] = flash_list("Error in validating DID Document:", entries)
                end

                if !retVal["infos"].nil? && retVal["infos"].count > 0
                    if retVal["infos"].first.is_a?(String)
                        info_text = retVal["infos"].first.to_s
                    else
                        infos = retVal.stringify_keys["infos"].map(&:stringify_keys)
                        if infos.any? { |e| e["error"].to_s != "" }
                            entries = infos.map { |e| flash_escape(e["value"].to_s.split("/").last.to_s + ": " + e["error"].to_s) }
                            info_text = flash_list("Consider JSON-LD representation by adding a JSON-LD Context:", entries)
                        else
                            entries = infos.map { |e| flash_message(e["message"]) }
                            info_text = flash_list("Notes on JSON-LD Context:", entries)
                        end
                    end
                    flash.now[:info] = info_text
                end
            end

    end

    # Flash messages are rendered as HTML. Every value that stems from the
    # validated document or from a remote service is escaped; only the list
    # markup and the fixed link to the DID Specification Registries are
    # emitted as markup. Plain strings put into the flash are escaped by the
    # view.
    def flash_escape(text)
        CGI.escapeHTML(text.to_s)
    end

    def flash_message(text)
        flash_escape(text).gsub(flash_escape(DID_REGISTRY_LINK), DID_REGISTRY_LINK)
    end

    def flash_list(title, entries)
        (flash_escape(title) + "<ul>" + entries.map { |e| "<li>" + e + "</li>" }.join + "</ul>").html_safe
    end

end
