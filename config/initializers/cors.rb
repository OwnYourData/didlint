# Any origin may call the API; browsers may read the header that tells how a
# did:oyd was resolved.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "*", headers: :any, methods: [:get, :post, :options], expose: ["X-DID-Resolved-Via"]
  end
end
