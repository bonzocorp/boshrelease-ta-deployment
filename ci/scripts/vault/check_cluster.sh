#!/bin/bash

exec >&2

set -e

source pipeline/ci/scripts/common.sh


function handshake(){
  safe target $VAULT_ADDR vault
  echo $VAULT_TOKEN | safe auth token
  safe set secret/handshake knock=knock
  response="$(safe get secret/handshake:knock)"
  if [ $response != "knock" ] ; then
    exit 1
  fi
}

handshake
