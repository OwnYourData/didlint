# DID Linter

DID Linter validates DID documents against the W3C [Decentralized Identifiers (DIDs) v1.0](https://www.w3.org/TR/did-core/) specification. The rules are described in a [SOyA](https://ownyourdata.github.io/soya/) structure: SHACL checks the structure of a document, and a separate step checks its JSON-LD `@context`. DID Linter resolves DIDs itself, or validates a DID document you provide.

[Semantic Overlay Architecture (SOyA)](https://ownyourdata.github.io/soya/) is a data model authoring and publishing platform with built-in validation and transformation. It builds on the W3C [Resource Description Framework (RDF)](https://en.wikipedia.org/wiki/Resource_Description_Framework) and describes data structures in YAML as bases with optional overlays.

The structure used for validation is pinned by its DRI in `config/initializers/constants.rb` (`SOYA_DID_DRI`) and reported by `GET /version`. The current one: [z2roahKVXPptAyHneXnyLHFUztYojEK3gLMnj3sTvsZcW](https://soya.ownyourdata.eu/z2roahKVXPptAyHneXnyLHFUztYojEK3gLMnj3sTvsZcW/yaml), published from [`soya/Did.yml`](soya/Did.yml) with soya-cli 0.18.4. The name `Did` in the SOyA repository always points to the most recently published version, which is not necessarily the pinned one.

## Online Service

DID Linter is available at https://didlint.ownyourdata.eu, with a web frontend and a REST API.

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
cat did_document.json | script/prep.sh | soya validate z2roahKVXPptAyHneXnyLHFUztYojEK3gLMnj3sTvsZcW
cat did_document.json | script/verify_context.rb
```

- `script/prep.sh [DRI]` wraps the DID document the way the service does before SHACL validation (`@graph` with `@type` `Did`, the structure as `@vocab`, set attributes as lists for structures that validate sets as lists).
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

To build the image yourself: `docker build -f docker/Dockerfile -t didlint .` (linux/amd64 and linux/arm64; the public instance runs linux/amd64).

Release images are built on GitHub rather than on a workstation: the workflow `image` (Actions tab, "Run workflow" with the tag from `kubernetes/didlint-deployment.yaml`) builds the image for linux/amd64, runs the unit tests and the regression checks online and offline against it, and only then pushes it to Docker Hub. It refuses a tag that already exists and needs the repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (a Docker Hub access token with write access to `oydeu/didlint`).

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
| `DIDLINT_OFFLINE` | `true` for the [offline mode](#offline-mode) | |
| `SOYA_STRUCTURE_DIR` | directory for structures fetched at runtime with `soya:fetch` | `storage/soya` |
| `SOYA_JS` | soya-js package for SHACL validation in offline mode | `/opt/soya-js` in the image |
| `DIDLINT_METHOD_STATUS_URL` | [status of the DID methods](#status-of-did-methods) shown on the start page; empty leaves the section out | https://ownyourdata.github.io/didlint/dif-methods.json |

### Offline Mode

With `DIDLINT_OFFLINE=true` an instance makes no outgoing connections at all:

- The SOyA structure comes from a local copy: a structure fetched at runtime (see below), otherwise the copy shipped in `soya/` (`<DRI>.json` as published, plus `soya-context.json`, which the structure imports).
- SHACL runs locally through soya-js, the same library soya-web-cli uses; the image contains it under `/opt/soya-js`. The unit tests check that it decides every recorded fixture exactly like soya-web-cli.
- `POST /api/validate` and the form for DID documents work as online. Everything that has to resolve a DID answers with HTTP 503 and `resolving DIDs is not available in offline mode`.
- `GET /version` reports `"mode": "offline"`.

```bash
docker run -d --name didlint --network none \
  -e RAILS_ENV=production -e RAILS_LOG_TO_STDOUT=TRUE -e RAILS_SERVE_STATIC_FILES=TRUE -e LANG=C.UTF-8 \
  -e allowed_hosts=localhost -e SECRET_KEY_BASE="$(openssl rand -hex 64)" -e DIDLINT_OFFLINE=true \
  oydeu/didlint:<tag>
```

`--network none` leaves the container without any network, so this example can only be checked from inside, e.g. with `docker exec didlint curl -s http://localhost:3000/version`. Online, the local copy is the fallback when the SOyA repository cannot be reached.

### Updating the SOyA Structure at Runtime

A running instance, online or offline, can switch to a newer structure without a new image, provided it can reach the SOyA repository for the moment:

```bash
bin/rails 'soya:fetch[Did]'
bin/rails soya:status
bin/rails soya:reset
```

- `soya:fetch` takes the version of `Did` tagged `current` (also `Did:<tag>` or a DRI), validates every fixture in `pytest/` against it locally and switches only if the verdicts match `pytest/expectations.json`; fixtures listed under `planned_changes` may change. Otherwise it stops and keeps the structure in use; `FORCE=1` switches anyway.
- The fetched structure is stored in `SOYA_STRUCTURE_DIR` and used from the next request on; `GET /version` then reports its DRI with `"did-dri-source": "fetched"`.
- `soya:reset` goes back to the pinned structure. A restart does so as well, unless `SOYA_STRUCTURE_DIR` is a persistent volume.
- The check uses the current encoding of set values; a structure that needs a different encoding comes with a new release.

In Kubernetes: `kubectl -n soya exec deploy/didlint -- bin/rails 'soya:fetch[Did]'` (with more than one replica, per pod).

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

After `SOYA_DID_DRI` changes, record the exchanges again with `bundle exec rails runner script/record_soya_fixtures.rb` and review the diff of `spec/fixtures/` and `soya/`. The tests of the offline validator run where `node` and soya-js are available (`SOYA_JS`), as in the image; elsewhere they are skipped.

### Regression Checks

`script/check_fixtures.py` (Python 3, standard library only) runs the fixtures in `pytest/` and compares the results with `pytest/expectations.json`:

```bash
python3 script/check_fixtures.py --url http://localhost:3000
python3 script/check_fixtures.py --structure
python3 script/check_fixtures.py --structure <DRI> --encoding list
```

`--url` checks a running instance: the web frontend, the files it loads (logo) and the API documentation; every response against `pytest/NN_output/`; that `/version` reports the structure pinned in `config/initializers/constants.rb`; and that `did:oyd` resolution returns the requested DID as `id`. With `--offline` it expects the instance in offline mode and every request that resolves a DID to be rejected. `--structure` validates the fixtures directly through soya-web-cli against a SOyA structure, without the context checks done in Ruby, and checks that the local copy in `soya/` equals the published structure.

**Before `SOYA_DID_DRI` is switched to a new structure, `--structure <new DRI>` must pass.** Intended changes in the verdicts are recorded in `pytest/expectations.json` and the affected `NN_output/` files in the same commit as the new DRI.

A changed `soya/Did.yml` is published with `cat soya/Did.yml | soya init-push --json` (soya-cli 0.18.5 or later), which prints the DRI the repository assigned; it has to match the version tagged `current` in https://soya.ownyourdata.eu/Did/info. The DRI can be computed before publishing: soya-js 0.10.6 or later calculates it from the output of `soya init` with `structureDri`.

The GitHub workflow `regression` runs the structure check, the unit tests, a container built from the commit and the same container in offline mode inside a Docker network without internet access on every push, and checks https://didlint.ownyourdata.eu daily. A candidate structure can be checked from the Actions tab with "Run workflow" and its DRI.

### Status of DID Methods

`status/methods.json` lists the methods that the Decentralized Identity Foundation [recommends](https://github.com/decentralized-identity/did-methods/tree/main/dif-recommended), and `did:oyd`, each with example DIDs. The workflow `methods` validates them daily with `script/check_methods.py` against https://didlint.ownyourdata.eu and publishes the result on GitHub Pages as https://ownyourdata.github.io/didlint/dif-methods.json; the start page shows it, fetched at most once per hour and never in offline mode. The workflow needs GitHub Pages with "Source: GitHub Actions" in the repository settings.

```bash
python3 script/check_methods.py --url http://localhost:3000 --output dif-methods.json
```

Every example DID gets one status: `conforms` (with the number of notes), `violations` (with the findings as the API returns them), `not_resolvable` (with the resolver's message) or `error` (no result, e.g. because the request limit of the Universal Resolver was reached); `since` is the time from which it has had this status. A DID without a result keeps its previous one, and `checked` tells when that was obtained. A result describes these DIDs, not every DID of a method. The example DIDs come from the DIF findings documents, the test identifiers of the Universal Resolver and, for `did:webvh`, the DIF repository didwebvh-implementations; `did:webplus` has none yet, because the Universal Resolver has no driver for it. GitHub disables scheduled workflows of a public repository after 60 days without activity; the date on the start page shows when the last check ran.

## Improve DID Linter

DID Linter shows how a SOyA structure can describe DID documents in a readable and machine-readable way, and how SOyA's validation reports violations. The structure does not yet cover the DID Core specification completely; please report issues and gaps in the [issue tracker](https://github.com/OwnYourData/didlint/issues).

Known gaps:

- A verification method type the structure does not list is tolerated: the document is not rejected because of its verification methods, and a note names the context that is not listed. Findings about all other members are reported as usual.
- The JSON-LD expansion check (`/api/validate_jsonld`) is not part of the verdict.
- DIDs of methods other than `did:oyd` are resolved through the public Universal Resolver at https://dev.uniresolver.io, which limits how many requests a client may send (at the time of writing 10 per 30 minutes; an instance counts as one client for all its users). When the limit is reached, DID Linter answers `Universal Resolver request limit reached, please try again later`; a DID document can still be checked by posting it.

A verification method of a type the structure lists has to carry the key in the representation that the [DID Specification Registries](https://www.w3.org/TR/did-spec-registries/#verification-method-types) give for that type. `Ed25519VerificationKey2018`, for example, comes with `publicKeyBase58` only, as in its JSON-LD context; for a JWK the type is `JsonWebKey2020`, for a multibase key `Multikey` or `Ed25519VerificationKey2020`.

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

[Apache License 2.0](LICENSE) - OwnYourData.eu

Releases up to and including 0.11.0 were published under the MIT License; [NOTICE](NOTICE) keeps its notice for the code contributed under it.
