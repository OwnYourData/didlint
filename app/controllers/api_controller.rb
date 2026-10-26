class ApiController < ApplicationController
    # The API is stateless and uses neither sessions nor cookies, so there is
    # no request to forge. CORS is handled by Rack::Cors (config/initializers/cors.rb).
    skip_forgery_protection

    rescue_from DidLint::StructureUnavailable do
        render json: {"valid": false, "error": "SOyA structure not available"},
               status: 502
    end
end
