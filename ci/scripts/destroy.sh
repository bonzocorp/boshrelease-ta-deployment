#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

function destroy() {
  bosh delete-deployment  \
    -d $BOSH_DEPLOYMENT \
    -n
}

generate_configs
authenticate_director
destroy
