class ApplicationController < ActionController::Base
	include ApplicationHelper

    def version
        soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
        soya_web_cli = ENV["SOYA_WEB_CLI"] || SOYA_WEB_CLI
        
        retVal = {}
        retVal["service"] = "DID Linter"
        retVal["version"] = VERSION.to_s
        web_cli_version = HTTParty.get(soya_web_cli + "/api/v1/version").parsed_response["version"] rescue nil
        if !web_cli_version.nil?
            retVal["soya-cli_version"] = web_cli_version
        end
        retVal["did-dri"] = soya_did_dri
        render json: retVal.to_json,
               status: 200
    end    

    def missing
        render json: {"error": "invalid path"},
               status: 404
    end

end
