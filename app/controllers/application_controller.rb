class ApplicationController < ActionController::Base
	include ApplicationHelper

    def version
        soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
        render json: {"service": "did linter", "version": VERSION.to_s, "soya-cli_version": soya_version.to_s, "did-dri": soya_did_dri}.to_json,
               status: 200
    end    

    def missing
        render json: {"error": "invalid path"},
               status: 404
    end

end
