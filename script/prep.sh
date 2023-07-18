#!/bin/bash

# Check if there is an input parameter
if [ "$#" -gt 0 ]; then
    soya_struct="$1"
else
    soya_struct="Did"
fi

# default context for SOyA validation
template='{
    "@version": 1.1,
    "did": "https://soya.ownyourdata.eu/%s/",
    "@vocab": "https://soya.ownyourdata.eu/%s/"}'
did_context=$(printf "$template" "$soya_struct" "$soya_struct")

# use all available inputs
echo $did_context "$(cat -)" | \
	# build basic structure with @context and @graph
	jq -s '{ "@context": .[0], "@graph":[ .[1] ] } | del(."@graph"[0]."@context")' | \
	# add @type information in @graph
	jq --arg soya_struct "$soya_struct" ".\"@graph\"[0] |= {\"@type\":\"$soya_struct\"} + ."
