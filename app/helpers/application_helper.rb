module ApplicationHelper
    Hash.include CoreExtensions

    def soya_version
        return "0.16.9"
    end

    # Returns the full title on a per-page basis.
    def full_title(page_title = '')
        base_title = "OwnYourData"
        if page_title.empty?
            base_title
        else
            page_title + " | " + base_title
        end
    end

    def did_resolve(did)
        msg = ""
        if did.start_with?("did:oyd:")
            ddo, msg = Oydid.read(did, {})
            if !ddo.nil?
                ddo = Oydid.w3c(ddo, {})
            end
        else
            begin
                uniresolver_response = HTTParty.get("https://dev.uniresolver.io/1.0/identifiers/" + did, timeout: 10)
            rescue Net::ReadTimeout
                return nil, "time out"
            rescue
                return nil, "invalid Uniresolver response"
            end
            ddo = JSON.parse(uniresolver_response)["didDocument"] rescue nil?
            if ddo.nil?
                err = JSON.parse(uniresolver_response)["didResolutionMetadata"]["error"] rescue nil
                if err.nil?
                    msg = JSON.parse(uniresolver_response)["didResolutionMetadata"]["errorMessage"] rescue nil
                    if msg.nil?
                        msg = "Uniresolver cannot resolve " + did
                    end
                else
                    msg = "Uniresolver cannot resolve " + did
                end
            end
        end
        return ddo, msg
    end

    def soya_prep(document)
        retVal = {}
        soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
        retVal["@context"] = {"@version": 1.1, "did": "https://soya.ownyourdata.eu/" + soya_did_dri + "/", "@vocab": "https://soya.ownyourdata.eu/" + soya_did_dri + "/"}
        document["@type"] = "Did"
        retVal["@graph"] = [document.except("@context")]

        return retVal
    end

    # expect json_input to be a valid JSON already formatted as string
    def soya_validate(json_input, orig_ddo)
        soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
        soya_validation_url = "https://soya-web-cli.ownyourdata.eu/api/v1/validate/" + soya_did_dri.to_s
        timeout = false
        begin
            response = HTTParty.post(soya_validation_url, 
                timeout: 10,
                headers: { 'Content-Type' => 'application/json' },
                body: json_input)
        rescue
            timeout = true
        end
        if timeout or response.nil? or response.code != 200
            return parse_soya_output({})
        else
            # check for alternative context
            first_error_message = response["results"].first["message"].first["value"] rescue ""
            if first_error_message.include?("invalid '")
                jsonld_validation_url = "https://soya-web-cli.ownyourdata.eu/api/v1/validate/jsonld"
                timeout = false
                begin
                    jld_response = HTTParty.post(jsonld_validation_url, 
                        timeout: 10,
                        headers: { 'Content-Type' => 'application/json' },
                        body: orig_ddo)
                rescue
                    timeout = true
                end
                if jld_response.parsed_response == []
                    vm_type = JSON.parse(orig_ddo).deep_find("type")
                    return {"valid": true, "infos":["'" + vm_type.to_s + "' is not yet listed as Verification Method Type in the <a href='https://www.w3.org/TR/did-spec-registries/#verification-method-types'>DID Specification Registries</a>"]}
                else
                    return parse_soya_output(response.to_json)
                end
            else
                # return parse_soya_output(response.parsed_response["data"].to_json)
                return parse_soya_output(response.to_json)
            end
        end

        # Command line
        # soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
        # cmd = "echo '#{json_input}' | soya validate " + soya_did_dri
        # out = nil

        # require 'open3'
        # Open3.popen3(cmd) {|stdin, stdout, stderr, wait_thr|
        #   pid = wait_thr.pid # pid of the started process.
        #   out = stdout.gets(nil)
        #   exit_status = wait_thr.value # Process::Status object returned.
        # }
        # return parse_soya_output(out)

    end

    def parse_soya_output(soya_stdout)
        # check for plain error message
        start_str = soya_stdout[0,16] rescue ""
        if start_str == "\e[31merror\e[39m:"
            return {"valid": false, "errors": [{"value":"soya-cli", "error": soya_stdout[soya_stdout.rindex("error:")+7, soya_stdout.length].strip}]}
            exit
        end

        # try to parse response
        result = JSON.parse(soya_stdout) rescue nil
        if result.nil?
            return {"valid": false, "errors": [{"value":"soya-cli", "error": "cannot validate input"}]}
        end
        if result["isValid"]
            return {"valid": true}
        end
        retVal = {"valid": false}
        result["results"].each do |r|
            msg = r["message"] rescue nil
            if msg == [] || msg.to_s == ""
                val = r["value"] rescue nil
                if val.nil?
                    val = r["severity"]["value"].to_s rescue nil
                end
                if val.to_s != ""
                    case val
                    when "http://www.w3.org/ns/shacl#Violation"
                        obj = {"value": "Verification Relationship", "error": "missing"}
                    else    
                        obj = {"value": r["value"], "error": "invalid"}
                    end
                    if retVal["errors"].nil?
                        retVal["errors"] = [obj]
                    else
                        retVal["errors"] << obj
                        retVal["errors"] = retVal["errors"].flatten
                    end
                end
            else
                obj = {"value": r["value"], "error": r["message"].first["value"]} rescue nil
                if !obj.nil?
                    if retVal["errors"].nil?
                        retVal["errors"] = [obj]
                    else
                        retVal["errors"] << obj
                        retVal["errors"] = retVal["errors"].flatten
                    end
                end
            end
        end
        return retVal
    end
end
