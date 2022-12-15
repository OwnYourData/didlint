# DID Lint
DID Lint provides services to validate conformance of DID Documents to the W3C Decentralised Identifier Specification. It uses overlay information from the [SOyA structure on DIDs](https://soya.ownyourdata.eu/Did/yaml) to validate inputs and identify any violations to the standard.

[Semantic Overlay Architecture (SOyA)](https://ownyourdata.github.io/soya/) is a data model authoring and publishing platform and also provides functionalities for validation and transformation. It builds on W3C [Resource Description Framework (RDF)](https://en.wikipedia.org/wiki/Resource_Description_Framework) and related semantic web technologies to provide a lightweight approach for data integration and exchange.

At the core of SOyA is a YAML-based data model for describing data structures with bases and optional overlays, which provide additional information and context. The DID Lint service uses the following SOyA structure for validating DID Documents: [click here](https://soya.ownyourdata.eu/Did/yaml).

## Usage

### On the Command Line

To validate DID documents on the command line make sure to have the soya-cli installed: https://github.com/OwnYourData/soya    

You can use a pre-built package from npmjs.com:
```bash
npm install -g soya-cli@latest
```

The validation includes a pre-processing step (to make the DID Document compliant with SOyA) and is available as a [small script here](https://github.com/OwnYourData/didlint/blob/main/script/prep.sh)    
example:    
```bash
cat did_document.json | ./script/prep.sh
```

The pre-preocessed JSON-LD document can then be validated with the `soya validate` command,    
complete example (including pre-processing) and using the [ SOyA structure defining `Did`](https://soya.ownyourdata.eu/Did):
```bash
cat did_document.json | ./script/prep.sh | soya validate Did
```

The output describes the result of the validation process (using a [SHACL](https://en.wikipedia.org/wiki/SHACL)) and lists any unmet constraints.


### With Docker

The above steps are bundled in an Docker image available here: https://hub.docker.com/r/oydeu/didlint    

Start the image with the following command:

```bash
docker run --name didlint -d -p 3000:3000 oydeu/didlint
```

and access validation features through exposed APIs on `http://localhost:3000` as described in the Swagger API documentation here: https://didlint.ownyourdata.eu/api-docs    

examples:

```bash
curl http://localhost:3000/api/validate/did:oyd:zQmZZbVygmbsxWXhP2BH5nW2RMNXSQA3eRqnzfkFXzH3fg1
cat did_document.jsonld | curl -H 'Content-Type: application/json' -d @- -X POST http://localhost:3000/api/validate
```

### Online Service

The DID Lint service is also available publicly here: https://didlint.ownyourdata.eu    
Use either the web frontend or the provided REST API to resolve DIDs and validate DID Documents.


## Improve DID Lint

This service is a Proof-of-Concept to demonstrate the validation overlay capabilities of SOyA, i.e., show-case an easy to understand but still machine-readable format to describe DID Documents and use the built-in mechanisms of SOyA to either validate conformance or list identified violations.

The current DID Document SOyA structure is most certainly not a complete and correct representation of the DID Core Spec and we would like to encourage everyone to report issues using the [GitHub Issue-Tracker](https://github.com/sem-con/sc-base/issues) .

If you want to contribute pull requests, please follow these steps:

1. Fork it!
2. Create a feature branch: `git checkout -b my-new-feature`
3. Commit changes: `git commit -am 'Add some feature'`
4. Push into branch: `git push origin my-new-feature`
5. Send a Pull Request

&nbsp;    

## About  

<img align="right" src="https://raw.githubusercontent.com/OwnYourData/didlint/main/app/assets/images/logo-ngi-ontochain-positive.png" height="150">This project has received funding from the European Union’s Horizon 2020 research and innovation program through the [NGI ONTOCHAIN program](https://ontochain.ngi.eu/) under cascade funding agreement No 957338.


<br clear="both" />

## License

[MIT License 2022 - OwnYourData.eu](https://raw.githubusercontent.com/OwnYourData/didlint/main/LICENSE)
