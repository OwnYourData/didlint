module ApplicationHelper
    def soya_version
        return "0.16.7"
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
                msg = JSON.parse(uniresolver_response)["didResolutionMetadata"]["errorMessage"] rescue nil
                if msg.nil?
                    msg = "Uniresolver cannot resolve " + did
                end
            end
        end
        return ddo, msg
    end

    def soya_prep(document)
        retVal = {}
        retVal["@context"] = {"@version": 1.1, "did": "https://soya.data-container.net/" + SOYA_DID_DRI + "/", "@vocab": "https://soya.data-container.net/" + SOYA_DID_DRI + "/"}
        document["@type"] = "Did"
        retVal["@graph"] = [document.except("@context")]

        return retVal
    end

    # expect json_input to be a valid JSON already formatted as string
    def soya_validate(json_input)
        cmd = "echo '#{json_input}' | soya validate " + SOYA_DID_DRI
        out = nil

        require 'open3'
        Open3.popen3(cmd) {|stdin, stdout, stderr, wait_thr|
          pid = wait_thr.pid # pid of the started process.
          out = stdout.gets(nil)
          exit_status = wait_thr.value # Process::Status object returned.
        }
        return parse_soya_output(out)

    end

    def parse_soya_output(soya_stdout)
        # check for plain error message
        if soya_stdout[0,16] == "\e[31merror\e[39m:"
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
                if val != ""
                    obj = {"value": r["value"], "error": "invalid (compliant type?)"}
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
