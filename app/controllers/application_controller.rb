class ApplicationController < ActionController::Base
	include ApplicationHelper

    def version
        soya_did_dri = DidLint::Structure.active_dri
        soya_web_cli = ENV["SOYA_WEB_CLI"] || SOYA_WEB_CLI
        
        retVal = {}
        retVal["service"] = "DID Linter"
        retVal["version"] = VERSION.to_s
        retVal["mode"] = DidLint.offline? ? "offline" : "online"
        if !DidLint.offline?
            web_cli_version = HTTParty.get(soya_web_cli + "/api/v1/version", timeout: 10).parsed_response["version"] rescue nil
            if !web_cli_version.nil?
                retVal["soya-cli_version"] = web_cli_version
            end
        end
        retVal["did-dri"] = soya_did_dri
        retVal["did-dri-source"] = soya_did_dri == DidLint::Structure.pinned_dri ? "pinned" : "fetched"
        retVal["oydid-gem"] = Gem.loaded_specs["oydid"]&.version.to_s
        retVal["oydid-resolver"] = ENV["OYDID_RESOLVER_URL"] || OYDID_RESOLVER_URL
        render json: retVal.to_json,
               status: 200
    end    

    def missing
        render json: {"error": "invalid path"},
               status: 404
    end

    private

    # resolves a DID and reports the path taken in the X-DID-Resolved-Via header
    def resolve_did(did)
        doc, msg, via = DidLint::Resolver.new.resolve(did)
        response.set_header("X-DID-Resolved-Via", via) if via
        [doc, msg]
    end

    def linter
        @linter ||= DidLint::Linter.new
    end

end
