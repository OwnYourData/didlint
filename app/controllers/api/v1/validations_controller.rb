module Api
    module V1
        class ValidationsController < ApiController
            def did
                did = params[:did].to_s
                if did == ""
                    render json: {"valid": false, "error": "invalid/missing DID"},
                           status: 422
                    return
                end
                input, msg = resolve_did(did)
                if input.nil?
                    render json: {"valid": false, "error": msg},
                           status: 422
                    return
                end

                render json: linter.validate(input).to_json,
                       status: 200
            end

            def did_jsonld
                did = params[:did].to_s
                if did == ""
                    render json: {"valid": false, "error": "invalid/missing DID"},
                           status: 422
                    return
                end
                ddoc, msg = resolve_did(did)
                if ddoc.nil?
                    render json: {"valid": false, "error": msg},
                           status: 422
                    return
                end

                if ddoc["@context"].nil?
                    render json: {"valid": false, "info": "not a JSON-LD document"},
                           status: 422
                    return
                end
                soya_web_cli = ENV["SOYA_WEB_CLI"] || SOYA_WEB_CLI
                jsonld_validation_url = soya_web_cli + "/api/v1/validate/jsonld"                
                timeout = false
                begin
                    jld_response = HTTParty.post(jsonld_validation_url, 
                        timeout: 10,
                        headers: { 'Content-Type' => 'application/json' },
                        body: ddoc.to_json)
                rescue
                    timeout = true
                end
                if timeout
                    render json: {"valid": false, "error": "JSON-LD validation service not reachable"},
                           status: 502
                elsif jld_response.code == 200
                    render json: {"valid": true},
                           status: 200
                else
                    if jld_response["error"].nil?
                        error_message = jld_response.parsed_response["message"] rescue "invalid JSON-LD"
                        render json: {"valid": false, "error": error_message},
                               status: 200
                    else
                        render json: {"valid": false,
                                      "message": jld_response["message"].to_s,
                                      "error": jld_response["error"]},
                               status: 200
                    end
                end
            end

            def did_jschema
                did = params[:did].to_s
                if did == ""
                    render json: {"valid": false, "error": "invalid/missing DID"},
                           status: 422
                    return
                end
                ddoc, msg = resolve_did(did)
                if ddoc.nil?
                    render json: {"valid": false, "error": msg},
                           status: 422
                    return
                end

                schema_src = ENV["JSON_SCHEMA_SOURCE"] || 'https://raw.githubusercontent.com/w3c/did-spec-registries/main/json_schemas/core.schema.json'
                schema = JSON.parse(HTTParty.get(schema_src)) rescue nil
                if schema.nil?
                    render json: {"error": "invalid schema source: '" + schema_src + "'"},
                           status: 404
                    return
                end
                # ugly hack to use available schema
                if schema["$schema"] == "http://json-schema.org/draft-07/schema#"
                    schema["$schema"] = "http://json-schema.org/draft-04/schema#"
                end

                errors = JSON::Validator.fully_validate(schema, ddoc)
                if errors == []
                    render json: {"valid": true},
                           status: 200
                else
                    render json: {"valid": false, "errors": errors},
                           status: 200
                end
            end

            def document
                begin
                    if params.include?("_json")
                        input = JSON.parse(params.to_json)["_json"]
                        other = JSON.parse(params.to_json).except("_json", "validation", "format", "controller", "action", "application")
                        if other != {}
                            input += [other]
                        end
                    else
                        input = JSON.parse(params.to_json).except("validation", "format", "controller", "action", "application")
                    end
                rescue => ex
                    render json: {"valid": false, "error": "can't parse input"},
                           status: 422
                    return
                end

                render json: linter.validate(input).to_json,
                       status: 200
            end

            def resolve
                did = params[:did].to_s
                if did == ""
                    render json: {"valid": false, "error": "invalid/missing DID"},
                           status: 422
                    return
                end
                input, msg = resolve_did(did)
                if input.nil?
                    render json: {"error": msg},
                           status: 422
                    return
                end

                render json: input,
                       status: 200
            end
        end
    end

end