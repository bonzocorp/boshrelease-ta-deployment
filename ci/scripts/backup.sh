#!/bin/bash

exec >&2
set -e

[[ "${DEBUG,,}" == "true" ]] && set -x

source pipeline/ci/scripts/common.sh

function backup(){
 bbr deployment -t $BOSH_ENVIRONMENT -u $BOSH_CLIENT -d $DEPLOYMENT_NAME --ca-cert=$BOSH_CA_CERT backup
 tar -cvzf $OUTPUT/backup.tgz $DEPLOYMENT_NAME_*
}

generate_configs
authenticate_director
backup
