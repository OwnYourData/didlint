module DidLint
    OFFLINE_MESSAGE = "not available in offline mode"

    # DIDLINT_OFFLINE=true runs DID Linter without any outgoing connection: the
    # SOyA structure comes from the local copy in soya/ and SHACL runs locally
    # through soya-js. Resolving DIDs is not available offline.
    def self.offline?
        %w[true 1 yes].include?(ENV["DIDLINT_OFFLINE"].to_s.strip.downcase)
    end
end
