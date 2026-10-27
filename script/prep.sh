#!/bin/bash
# Prepares a DID document (stdin) for "soya validate", like the DID Linter service
# does (soya_prep in app/services/did_lint/linter.rb): the structure becomes
# @vocab, and if the structure validates sets as lists, the set attributes of
# Did are encoded as lists.
# usage: cat did_document.json | script/prep.sh [DRI] | soya validate DRI
# Without DRI the structure pinned in config/initializers/constants.rb is used.

root="$(dirname "$0")/.."
dri="${1:-${SOYA_DID_DRI:-$(sed -n 's/^SOYA_DID_DRI *= *"\(.*\)"/\1/p' "$root/config/initializers/constants.rb")}}"
repo="${SOYA_REPO:-https://soya.ownyourdata.eu}"

if [ -f "$root/soya/$dri.json" ]; then
    structure="$(cat "$root/soya/$dri.json")"
else
    structure="$(curl -s "$repo/$dri")"
fi
lists="$(printf '%s' "$structure" | jq -c '
    if any(.["@graph"][]; .["@type"] == "OverlayValidation" and (tostring | contains("rdf:rest")))
    then [.["@graph"][]
          | select(.["soya:containerType"] == "set" and ((.domain | if type == "array" then . else [.] end) | index("Did") != null))
          | .["@id"]]
    else [] end')" || exit 1

jq --arg base "$repo/$dri/" --argjson lists "$lists" '{
    "@context": ({"@version": 1.1, "did": $base, "@vocab": $base}
                 + ($lists | map({(.): {"@container": "@list"}}) | add // {})),
    "@graph": [{"@type": "Did"} + del(."@context")]
}'
