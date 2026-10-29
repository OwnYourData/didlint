# Universal Resolver of OwnYourData

https://uniresolver.ownyourdata.eu is an instance of the [Universal Resolver](https://github.com/decentralized-identity/universal-resolver) of the Decentralized Identity Foundation, operated by [OwnYourData](https://www.ownyourdata.eu/en/). It resolves the methods listed below; [DID Linter](https://didlint.ownyourdata.eu) uses it for every method except `did:oyd`, which it resolves itself.

```bash
curl https://uniresolver.ownyourdata.eu/1.0/identifiers/did:webplus:ledgerdomain.github.io:did-webplus-spec:uFiANVlMledNFUBJNiZPuvfgzxvJlGGDBIpDFpM4DXW6Bow
curl -H 'Accept: application/did-resolution' https://uniresolver.ownyourdata.eu/1.0/identifiers/did:web:danubetech.com
curl https://uniresolver.ownyourdata.eu/1.0/methods
curl https://uniresolver.ownyourdata.eu/1.0/testIdentifiers
```

The API is the one of the Universal Resolver (`/1.0/identifiers/{did}`, `/1.0/methods`, `/1.0/testIdentifiers`, `/1.0/properties`, `/1.0/traits`). A method that is not listed answers with HTTP 501 and `METHOD_NOT_SUPPORTED`; it is not forwarded to another Universal Resolver.

The start page https://uniresolver.ownyourdata.eu resolves a DID in the browser and links the result to DID Linter. It is a static page in [`frontend/`](frontend/) and calls only the API of this host: no fonts, scripts or data from other servers (its Content Security Policy allows nothing else).

## Methods

| Method | Driver image |
|---|---|
| `did:cid` | `ghcr.io/archetech/uni-resolver-driver-did-cid`, which asks the gatekeeper https://archon.technology |
| `did:ethr` | `uport/uni-resolver-driver-did-uport` |
| `did:hedera` | `ghcr.io/hiero-ledger/uni-resolver-driver-did-hedera` |
| `did:webplus` | `ghcr.io/ledgerdomain/did-webplus-urd` |
| `did:webvh` | `ghcr.io/decentralized-identity/uni-resolver-driver-did-webvh` |
| `did:oyd` | none: forwarded to the [OYDID resolver](https://resolver.ownyourdata.eu) |
| `did:web` | `uport/uni-resolver-driver-did-uport` |
| `did:key` (Ed25519, X25519, secp256k1), `did:jwk`, `did:pkh`, `did:tz` | `ghcr.io/spruceid/didkit-http` |
| `did:key` (P-256, P-384, P-521, BLS12-381, RSA) | `universalresolver/driver-did-key` |

The first five are the methods the Decentralized Identity Foundation [recommends](https://github.com/decentralized-identity/did-methods/tree/main/dif-recommended).

## Operation

- [`1-uniresolver.yaml`](1-uniresolver.yaml): namespace `uniresolver`, uni-resolver-web with its configuration (`application.yml`: which pattern goes to which driver, and the test identifiers), ingress and certificate.
- [`2-drivers.yaml`](2-drivers.yaml): one deployment and service per driver.
- [`3-frontend.yaml`](3-frontend.yaml) and [`frontend/`](frontend/): the start page, served by an unprivileged nginx; [`kustomization.yaml`](kustomization.yaml) turns the files in `frontend/` into ConfigMaps whose names change with their content, so a changed page rolls out by itself.
- Apply everything with `kubectl apply -k kubernetes/uniresolver/` (not `-f`: the directory holds a kustomization).
- All images are pinned by digest. To update a driver, look up its current version in the [docker-compose.yml](https://github.com/decentralized-identity/universal-resolver/blob/main/docker-compose.yml) of the Universal Resolver, change tag and digest, apply, and resolve the test identifier of the method.
- The ingress limits requests to 300 per minute (`limit-rpm`, with the default burst of five times that). It does not see client addresses, so the limit applies to all clients together. DID Linter in the same cluster uses the service `uni-resolver-web.uniresolver:8080` directly and is not affected.
- Resolution results of the drivers are not stored, except by the `did:webplus` driver, which keeps verified DID documents in an SQLite file in an `emptyDir` volume (lost when the pod restarts). uni-resolver-web logs each requested DID and its result.

## License

The Universal Resolver and its drivers are published by their authors under their own licenses; the configuration in this directory is part of DID Linter and licensed under the [Apache License 2.0](../../LICENSE).
