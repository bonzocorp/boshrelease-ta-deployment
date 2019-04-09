#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

function restore(){
  bbr deployment -t $BOSH_ENVIRONMENT -u $BOSH_CLIENT -d $DEPLOYMENT_NAME --ca-cert=$BOSH_CA_CERT restore --artifact-path backup/*
}

generate_configs
authenticate_director
restore
