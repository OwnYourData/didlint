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
        uniresolver_url = ENV["UNIRESOLVER_URL"] || UNIRESOLVER_URL
        msg = ""
        if did.start_with?("did:oyd:")
            ddo, msg = Oydid.read(did, {})
            if !ddo.nil?
                ddo = Oydid.w3c(ddo, {})
            end
        else
            begin
                uniresolver_response = HTTParty.get(uniresolver_url + "/1.0/identifiers/" + did, timeout: 10)
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
        soya_repo = ENV["SOYA_REPO"] || SOYA_REPO
        retVal["@context"] = {"@version": 1.1, "did": soya_repo + "/" + soya_did_dri + "/", "@vocab": soya_repo + "/" + soya_did_dri + "/"}
        document["@type"] = "Did"
        retVal["@graph"] = [document.except("@context")]

        return retVal
    end

    # expect json_input to be a valid JSON already formatted as string
    # process for validating a DID Document
    # 1) it must be a valid JSON-LD
    #    exception: only if it has "@context"
    # 2) perform SHACL validation
    def soya_validate(json_input, orig_ddo)
        soya_did_dri = ENV["SOYA_DID_DRI"] || SOYA_DID_DRI
        soya_web_cli = ENV["SOYA_WEB_CLI"] || SOYA_WEB_CLI
        soya_validation_url = soya_web_cli + "/api/v1/validate/" + soya_did_dri.to_s
        jsonld_validation_url = soya_web_cli + "/api/v1/validate/jsonld"

        at_context = JSON.parse(orig_ddo)["@context"] rescue nil
        if !at_context.nil?
            timeout = false
            begin
                jld_response = HTTParty.post(jsonld_validation_url, 
                    timeout: 10,
                    headers: { 'Content-Type' => 'application/json' },
                    body: orig_ddo)
            rescue
                timeout = true
            end
            if jld_response.code != 200
                error_message = jld_response.parsed_response["message"] rescue "invalid JSON-LD"
                return {"valid": false, "errors": [{"value":"jsonld-validation", "error": error_message}]}
            end
        end

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
            return parse_soya_output(response.to_json)
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
