class ApplicationController < ActionController::Base
	include ApplicationHelper

    def version
        render json: {"service": "did linter", "version": VERSION.to_s, "soya-version": soya_version.to_s, "did-dri": SOYA_DID_DRI.to_s}.to_json,
               status: 200
    end    

    def missing
        render json: {"error": "invalid path"},
               status: 404
    end

end
