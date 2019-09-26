#!/bin/bash

exec >&2

set -e

source pipeline/ci/scripts/common.sh


function create_policy(){
  local file_path=$1
  local file_name=$(basename $1)
  local policy_name=${file_name//\.hcl/}
  safe target $VAULT_ADDR vault
  echo $VAULT_TOKEN | safe auth token
  safe vault policy write $policy_name $file_path
}

for policy_file in $POLICY_FILES ;do
  create_policy $policy_file
done

