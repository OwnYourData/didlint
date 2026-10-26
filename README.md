# DID Lint

DID Lint validates DID documents against the W3C [Decentralized Identifiers (DIDs) v1.0](https://www.w3.org/TR/did-core/) specification. The rules are described in a [SOyA](https://ownyourdata.github.io/soya/) structure: SHACL checks the structure of a document, and a separate step checks its JSON-LD `@context`. DID Lint resolves DIDs itself, or validates a DID document you provide.

[Semantic Overlay Architecture (SOyA)](https://ownyourdata.github.io/soya/) is a data model authoring and publishing platform with built-in validation and transformation. It builds on the W3C [Resource Description Framework (RDF)](https://en.wikipedia.org/wiki/Resource_Description_Framework) and describes data structures in YAML as bases with optional overlays.

The structure used for validation is pinned by its DRI in `config/initializers/constants.rb` (`SOYA_DID_DRI`) and reported by `GET /version`. The current one: [z3wmSSwhcQN4bgJHtgYqSLmdqRvv8Tnv189krACn1GtJE](https://soya.ownyourdata.eu/z3wmSSwhcQN4bgJHtgYqSLmdqRvv8Tnv189krACn1GtJE/yaml). The name `Did` in the SOyA repository always points to the most recently published version, which is not necessarily the pinned one.

## Online Service

DID Lint is available at https://didlint.ownyourdata.eu, with a web frontend and a REST API.

```bash
curl https://didlint.ownyourdata.eu/api/validate/did:oyd:zQmZZbVygmbsxWXhP2BH5nW2RMNXSQA3eRqnzfkFXzH3fg1
cat did_document.json | curl -H 'Content-Type: application/json' -d @- -X POST https://didlint.ownyourdata.eu/api/validate
```

| Endpoint | Purpose |
|---|---|
| `GET /api/validate/{did}` | resolve a DID and validate its DID document |
| `POST /api/validate` | validate the DID document in the request body |
| `GET /api/resolve/{did}` | resolve a DID and return its DID document |
| `GET /api/validate_jsonld/{did}` | check the DID document as JSON-LD (not part of the verdict) |
| `GET /api/validate_jschema/{did}` | validate the DID document against the JSON Schema of the DID Specification Registries |
| `GET /version` | version, SOyA structure and resolver configuration |

All `/api/` paths are also available below `/api/v1/`. The full description is in [Swagger](https://didlint.ownyourdata.eu/api-docs) (source: `swagger/v1/swagger.yaml`).

`did:oyd` is resolved through the [OYDID resolver](https://resolver.ownyourdata.eu); if it cannot be reached, the bundled oydid gem resolves locally. The response header `X-DID-Resolved-Via` (`http` or `gem`) shows which path answered. All other methods are resolved through the [Universal Resolver](https://dev.uniresolver.io).

## On the Command Line

The validation can be reproduced with [soya-cli](https://github.com/OwnYourData/soya) and [jq](https://jqlang.org):

```bash
npm install -g soya-cli@latest
cat did_document.json | script/prep.sh | soya validate z3wmSSwhcQN4bgJHtgYqSLmdqRvv8Tnv189krACn1GtJE
cat did_document.json | script/verify_context.rb
```

- `script/prep.sh [DRI]` wraps the DID document the way the service does before SHACL validation (`@graph` with `@type` `Did`, the structure as `@vocab`).
- `soya validate` prints the SHACL report of the structure.
- `script/verify_context.rb [DRI]` (Ruby, standard library only) checks the `@context` against the context constraints of the structure, which SHACL cannot see.

Without `DRI`, both scripts use the structure pinned in `config/initializers/constants.rb`. `script/iterate.sh` validates a list of DIDs with the public service and prints one line per DID.

## With Docker

Images are published as [oydeu/didlint](https://hub.docker.com/r/oydeu/didlint) with dated tags (`YYMMDD`); the tag deployed at didlint.ownyourdata.eu is the one in `kubernetes/didlint-deployment.yaml`.

```bash
docker run -d --name didlint -p 3000:3000 \
  -e RAILS_ENV=production -e RAILS_LOG_TO_STDOUT=TRUE -e RAILS_SERVE_STATIC_FILES=TRUE -e LANG=C.UTF-8 \
  -e allowed_hosts=localhost -e SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  oydeu/didlint:<tag>
curl http://localhost:3000/version
```

To build the image yourself: `docker build -f docker/Dockerfile -t didlint .`

### Configuration

| Variable | Meaning | Default |
|---|---|---|
| `RAILS_ENV` | `production` for a deployment | |
| `RAILS_LOG_TO_STDOUT` | `TRUE` to log to the console | |
| `RAILS_SERVE_STATIC_FILES` | `TRUE` unless a web server in front serves `public/` | |
| `LANG` | `C.UTF-8` | |
| `allowed_hosts` | host names the service answers to, comma-separated (e.g. `didlint.ownyourdata.eu`) | |
| `SECRET_KEY_BASE` | random value, e.g. from `openssl rand -hex 64`; never committed | |
| `SOYA_DID_DRI` | SOyA structure used for validation | pinned in `config/initializers/constants.rb` |
| `SOYA_REPO` | SOyA repository that serves the structure | https://soya.ownyourdata.eu |
| `SOYA_WEB_CLI` | SHACL and JSON-LD validation service | https://soya-web-cli.ownyourdata.eu |
| `OYDID_RESOLVER_URL` | resolver for `did:oyd` | https://resolver.ownyourdata.eu |
| `UNIRESOLVER_URL` | Universal Resolver for all other methods | https://dev.uniresolver.io |
| `JSON_SCHEMA_SOURCE` | JSON Schema for `/api/validate_jschema` | `core.schema.json` of the DID Specification Registries |

### Kubernetes

`kubernetes/didlint-deployment.yaml` is the manifest of the public instance (namespace, deployment, service, ingress, certificate). `SECRET_KEY_BASE` comes from the secret `didlint-skb`, which has to exist before the first rollout:

```bash
kubectl -n soya create secret generic didlint-skb --from-literal=SECRET_KEY_BASE="$(openssl rand -hex 64)"
```

## Tests

### Unit Tests

The validation pipeline (`app/services/did_lint/`) has unit and request tests that run offline: they replay recorded responses of soya-web-cli, the SOyA repository and the OYDID resolver from `spec/fixtures/`, check every fixture in `pytest/` against its expected output, and check that `swagger/v1/swagger.yaml` documents exactly the routed API.

```bash
bundle exec rspec
```

Inside the image, which leaves the test gems out:

```bash
docker run --rm -e RAILS_ENV=test -e BUNDLE_WITHOUT= oydeu/didlint:<tag> sh -c 'bundle install --quiet && bundle exec rspec'
```

After `SOYA_DID_DRI` changes, record the exchanges again with `bundle exec rails runner script/record_soya_fixtures.rb` and review the diff of `spec/fixtures/`.

### Regression Checks

`script/check_fixtures.py` (Python 3, standard library only) runs the fixtures in `pytest/` and compares the results with `pytest/expectations.json`:

```bash
python3 script/check_fixtures.py --url http://localhost:3000
python3 script/check_fixtures.py --structure
python3 script/check_fixtures.py --structure <DRI> --encoding list
```

`--url` checks a running instance: the web frontend, its assets and the API documentation; every response against `pytest/NN_output/`; that `/version` reports the structure pinned in `config/initializers/constants.rb`; and that `did:oyd` resolution returns the requested DID as `id`. `--structure` validates the fixtures directly through soya-web-cli against a SOyA structure, without the context checks done in Ruby.

**Before `SOYA_DID_DRI` is switched to a new structure, `--structure <new DRI>` must pass.** Intended changes in the verdicts are recorded in `pytest/expectations.json` and the affected `NN_output/` files in the same commit as the new DRI.

The GitHub workflow `regression` runs the structure check, the unit tests and a container built from the commit on every push, and checks https://didlint.ownyourdata.eu daily. A candidate structure can be checked from the Actions tab with "Run workflow" and its DRI.

## Improve DID Lint

DID Lint shows how a SOyA structure can describe DID documents in a readable and machine-readable way, and how SOyA's validation reports violations. The structure does not yet cover the DID Core specification completely; please report issues and gaps in the [issue tracker](https://github.com/OwnYourData/didlint/issues).

To contribute:

1. Fork the repository.
2. Create a feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push the branch: `git push origin my-new-feature`
5. Open a pull request.

&nbsp;

## About

<img align="right" src="https://raw.githubusercontent.com/OwnYourData/dc-intermediary/main/res/logo-ngi-trustchain-positive.png" height="100">This project has received funding from the European Union’s Horizon 2020 research and innovation program through the [NGI ONTOCHAIN program](https://ontochain.ngi.eu/) under cascade funding agreement No 957338 and the [NGI TRUSTCHAIN program](https://trustchain.ngi.eu/) under cascade funding agreement No 101093274.

<br clear="both" />

## License

[MIT License 2024 - OwnYourData.eu](https://raw.githubusercontent.com/OwnYourData/didlint/main/LICENSE)
