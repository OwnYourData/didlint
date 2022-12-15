# DID Lint
DID Lint provides services to validate conformance of DID Documents to the W3C Decentralised Identifier Specification. It uses overlay information from the [SOyA structure on DIDs](https://soya.ownyourdata.eu/Did/yaml) to validate inputs and identify any violations to the standard.

[Semantic Overlay Architecture (SOyA)](https://ownyourdata.github.io/soya/) is a data model authoring and publishing platform and also provides functionalities for validation and transformation. It builds on W3C [Resource Description Framework (RDF)](https://en.wikipedia.org/wiki/Resource_Description_Framework) and related semantic web technologies to provide a lightweight approach for data integration and exchange.

At the core of SOyA is a YAML-based data model for describing data structures with bases and optional overlays, which provide additional information and context. The DID Lint service uses the following SOyA structure for validating DID Documents: [click here](https://soya.ownyourdata.eu/Did/yaml).

## Usage
Get the image for the base container from Dockerhub: https://hub.docker.com/r/semcon/sc-base/

Perform the following steps to start the base container:
1. Start the container  
   `docker run -d -p 3000:3000 semcon/sc-base`
2. Initialize the container  
   `curl -H "Content-Type: application/json" -d "$(< init.json)" -X POST http://localhost:3000/api/desc`
3. Write data into the container  
   `curl -H "Content-Type: application/json" -d '{"my": "data"}' -X POST http://localhost:3000/api/data`
4. Read data from container  
   `curl http://localhost:3000/api/data`
5. create image with data  
   `docker commit container_name semcon/data-example`  
   and afterwards you can start the container and access the data:  
   `docker run -d -p 3001:3000 semcon/data-example`  
   `curl http://localhost:3001/api/data`

More examples and step-by-step instructions are available in a tutorial here: https://github.com/sem-con/Tutorials/


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

This project has received funding from the European Union’s Horizon 2020 research and innovation program through the [NGI ONTOCHAIN program](https://ontochain.ngi.eu/) under cascade funding agreement No 957338.

<img align="right" src="https://raw.githubusercontent.com/OwnYourData/didlint/main/app/assets/images/logo-ngi-ontochain-positive.png" height="150">

<br clear="both" />

## License

[MIT License 2022 - OwnYourData.eu](https://raw.githubusercontent.com/OwnYourData/didlint/main/LICENSE)
