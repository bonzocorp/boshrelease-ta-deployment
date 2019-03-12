#!/bin/bash

exec >&2
set -e

if [[ "${DEBUG,,}" == "true" ]]; then
  set -x
  echo "Environment Variables:"
  env

fi

OUTPUT=output
mkdir -p $OUTPUT

function load_custom_ca_certs(){
  if [[ ! -z "$CUSTOM_ROOT_CA" ]] ; then
    echo -e "$CUSTOM_ROOT_CA" > /etc/ssl/certs/custom_root_ca.crt
  fi

  if [[ ! -z "$CUSTOM_INTERMEDIATE_CA" ]] ; then
    echo -e "$CUSTOM_INTERMEDIATE_CA" > /etc/ssl/certs/custom_intermediate_ca.crt
  fi

  update-ca-certificates
}

function log() {
  green='\033[0;32m'
  reset='\033[0m'

  echo -e "${green}$1${reset}"
}

function error() {
  red='\033[0;31m'
  reset='\033[0m'

  echo -e "${green}$1${reset}"
}

function check_if_exists(){
  ERROR_MSG=$1
  CONTENT=$2

  if [[ -z "$CONTENT" ]] || [[ "$CONTENT" == "null" ]]; then
    echo $ERROR_MSG
    exit 1
  fi
}
function check_if_file_exists(){
  FILE=$1

  if [[ ! -f $FILE ]]; then
    log "Required file $FILE not found..."
    exit 1
  fi
}

function generate_configs(){
  log "Generating config files ..."

  if [[ ! -z "$VARS_FILE" ]] ; then
    spruce merge $VARS_FILE 2>/dev/null > $OUTPUT/vars.yml
  fi

  if [[ ! -z "$UAA_CLIENTS_FILE" ]] ; then
    spruce merge $UAA_CLIENTS_FILE 2>/dev/null > $OUTPUT/uaa_clients.yml
  fi

  if [[ ! -z "$STORE_FILE" ]] ; then
    spruce merge $STORE_FILE 2>/dev/null > $OUTPUT/store.yml
  fi

  if [[ ! -z "$CREDS_FILE" ]] ; then
    spruce merge $CREDS_FILE 2>/dev/null > $OUTPUT/creds.yml
  fi

}

function authenticate_director() {
  export BOSH_NON_INTERACTIVE=true
  export BOSH_CLIENT=$( bosh int $OUTPUT/creds.yml --path /bosh/client )
  export BOSH_CLIENT_SECRET=$( bosh int $OUTPUT/creds.yml --path /bosh/client_secret )
  export BOSH_ENVIRONMENT=$( bosh int $OUTPUT/creds.yml --path /bosh/environment)

  export BOSH_CA_CERT=$OUTPUT/bosh.crt
  bosh int $OUTPUT/creds.yml --path /bosh/ca_cert > $BOSH_CA_CERT
}
