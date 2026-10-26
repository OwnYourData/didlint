#!/bin/bash

# Validates a list of DIDs (one per line on stdin) with the public DID Lint
# service and prints one summary line per DID. Example with the test
# identifiers of the Universal Resolver (needs yq and jq):
# curl -s https://raw.githubusercontent.com/decentralized-identity/universal-resolver/main/uni-resolver-web/src/main/resources/application.yml | yq -o json .uniresolver.drivers | jq -r '.[].testIdentifiers | .[]' | script/iterate.sh

while read -r did; do
	# response=$(curl -s https://didlint.ownyourdata.eu/api/validate/$did | jq '.valid')
	# echo "$response - $did"
	response=$(curl -s https://didlint.ownyourdata.eu/api/validate/$did)
	response="$(echo $response | tr '\n' ' ' | jq -c)"
	if [ "$(echo $response | jq '.valid')" = "true" ]; then
		echo "valid - $did"
	else
		if [ "$(echo $response | jq '.error')" = null ]; then
			echo "invalid ( $(echo $response | jq -r '.errors[0].value' | awk -F / '{print $NF}'): $(echo $response | jq -r '.errors[0].error' | tr '\n' ' ') ) - $did"
		else
			echo "invalid ($(echo $response | jq -r .error | cut -c1-30 | tr '\n' ' ' )...) - $did"
		fi
	fi
done