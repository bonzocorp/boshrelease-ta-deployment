#!/bin/bash

exec >&2

set -e

source pipeline/ci/scripts/common.sh


function create_policy(){
  local policy_file=$1
  local policy_name=${policy_file//\.hcl/}
  safe target $VAULT_ADDR vault
  echo $VAULT_TOKEN | safe auth token
  safe vault policy write $policy_name $policy_file
}

for policy_file in $POLICY_FILES ;do
  create_policy policy_file
done

