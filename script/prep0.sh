#!/bin/bash

# default context for SOyA validation
did_context='{
    "@version": 1.1,
    "did": "https://soya.ownyourdata.eu/Did/",
    "@vocab": "https://soya.ownyourdata.eu/Did/"}'

# use all available inputs
echo $did_context "$(cat -)" | \
	# build basic structure with @context and @graph
	jq -s '{ "@context": .[0], "@graph":[ .[1] ] } | del(."@graph"[0]."@context")' | \
	# add @type information in @graph
	jq '."@graph"[0] |= {"@type":"Did"} + .' 