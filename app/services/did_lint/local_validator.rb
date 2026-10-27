require "open3"

module DidLint
    # SHACL validation in a local soya-js process (offline mode). Returns the
    # same result as the validate endpoint of soya-web-cli.
    class LocalValidator
        TIMEOUT = 30
        SCRIPT = Rails.root.join("lib/soya/validate.js").to_s

        class Failed < StandardError; end

        def self.soya_js
            ENV["SOYA_JS"].presence || "/opt/soya-js"
        end

        def self.available?
            File.file?(File.join(soya_js, "dist/overlays/validate.js")) &&
                system("node", "--version", out: File::NULL, err: File::NULL)
        end

        def validate(structure, data)
            input = { "structure" => structure, "data" => data }.to_json
            Open3.popen3({ "SOYA_JS" => self.class.soya_js }, "node", SCRIPT) do |stdin, stdout, stderr, wait|
                out = Thread.new { stdout.read }
                err = Thread.new { stderr.read }
                begin
                    stdin.write(input)
                rescue Errno::EPIPE
                    nil
                end
                stdin.close
                finished = wait.join(TIMEOUT)
                unless finished
                    begin
                        Process.kill("KILL", wait.pid)
                    rescue Errno::ESRCH
                        nil
                    end
                end
                # always drain both pipes before the block closes them
                output = out.value
                errors = err.value
                raise Failed, "soya-js did not answer within #{TIMEOUT}s" unless finished
                raise Failed, errors.to_s.strip.presence || "soya-js failed" unless wait.value.success?
                JSON.parse(output)
            end
        rescue Errno::ENOENT
            raise Failed, "node is not installed"
        rescue JSON::ParserError
            raise Failed, "invalid output from soya-js"
        end
    end
end
