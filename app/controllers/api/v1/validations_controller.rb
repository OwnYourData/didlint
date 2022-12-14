module Api
    module V1
        class ValidationsController < ApiController
            include ApplicationHelper

            def did
                did = params[:did].to_s
                puts "Did: " + did
                if did == ""
                    render json: {"valid": false, "error": "invalid/missing DID"},
                           status: 422
                    return
                end
                input, msg = did_resolve(did)
                if input.nil?
                    render json: {"valid": false, "error": msg},
                           status: 422
                    return
                end

                puts "Input DID Document:"
                puts input.to_json

                # pre-process DID Document
                ddo = soya_prep(input)

                # validation
                retVal = soya_validate(ddo.to_json)

                # response
                render json: retVal.to_json, 
                       status: 200
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

                puts "Input DID Document:"
                puts input.to_json

                # pre-process DID Document
                ddo = soya_prep(input)

                # validation
                retVal = soya_validate(ddo.to_json)

                # response
                render json: retVal.to_json, 
                       status: 200
            end

            def resolve
                did = params[:did].to_s
                puts "Did: " + did
                if did == ""
                    render json: {"valid": false, "error": "invalid/missing DID"},
                           status: 422
                    return
                end
                input, msg = did_resolve(did)
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