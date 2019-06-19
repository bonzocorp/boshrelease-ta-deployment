#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

function authenticate_director() {
  export BOSH_CLIENT=$( bosh int $OUTPUT/creds.yml --path /bosh/client )
  export BOSH_CLIENT_SECRET=$( bosh int $OUTPUT/creds.yml --path /bosh/client_secret )
  export BOSH_ENVIRONMENT=$( bosh int $OUTPUT/creds.yml --path /bosh/environment)

  export BOSH_CA_CERT=$OUTPUT/bosh.crt
  bosh int $OUTPUT/creds.yml --path /bosh/ca_cert > $BOSH_CA_CERT
}

function update_runtime_config() {
  bosh -n update-runtime-config $OUTPUT/runtime-config.yml
}


generate_configs
authenticate_director
update_runtime_config
