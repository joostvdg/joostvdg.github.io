#!/bin/bash
TAGNAME="joostvdg-github-io-image"

echo "# Building new image with tag: $TAGNAME"
docker build --tag=$TAGNAME .
