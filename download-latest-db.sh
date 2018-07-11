#!/bin/bash

GITHUB_PROTO=${1:-https}
GITHUB_URL=$GITHUB_PROTO://github.com/byuccl/prjxray-db.git
rm -rf database
git clone $GITHUB_URL database
