#!/bin/bash
# Prepares a DID document (stdin) for "soya validate", like the DID Lint service
# does (soya_prep in app/services/did_lint/linter.rb).
# usage: cat did_document.json | script/prep.sh [DRI] | soya validate DRI
# Without DRI the structure pinned in config/initializers/constants.rb is used.

dri="${1:-${SOYA_DID_DRI:-$(sed -n 's/^SOYA_DID_DRI *= *"\(.*\)"/\1/p' "$(dirname "$0")/../config/initializers/constants.rb")}}"
repo="${SOYA_REPO:-https://soya.ownyourdata.eu}"

jq --arg base "$repo/$dri/" '{
    "@context": {"@version": 1.1, "did": $base, "@vocab": $base},
    "@graph": [{"@type": "Did"} + del(."@context")]
}'
