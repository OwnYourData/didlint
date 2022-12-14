class ApplicationController < ActionController::Base
	include ApplicationHelper

    def home
        output = "<html><head><title>DID Linter</title>"
        output +="</head><body>"
        output +="<h1>DID Lint - The DID Validator</h1>"
        output +="<p>Version: " + VERSION.to_s + " (soya v" + soya_version.to_s + ")</p>"
        output +="<p>Find more information here:</p><ul>"
        output +='<li>W3C DID Core Spec: <a href="https://github.com/w3c/did-core">https://github.com/w3c/did-core</a></li>'
        output +='<li>SOyA Specification: <a href="https://ownyourdata.github.io/soya/">https://ownyourdata.github.io/soya/</a></li>'
        output +='<li>DID SOyA Structure: <a href="https://soya.ownyourdata.eu/Did/yaml">https://soya.ownyourdata.eu/Did/yaml</a></li>'
        output +='<li>Github: <a href="https://github.com/OwnYourData/didlint/">https://github.com/OwnYourData/didlint/</a></li>'
        output +="</ul></body></html>" 
        render html: output.html_safe, 
               status: 200
    end

    def version
        render json: {"service": "oydid linter", "version": VERSION.to_s, "soya-version": soya_version.to_s}.to_json,
               status: 200
    end    

    def missing
        render json: {"error": "invalid path"},
               status: 404
    end

end
