#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

function update_runtime_config() {
  local bosh_args=""

  generate_releases_version_file

  bosh -n interpolate \
    --vars-store $OUTPUT/store.yml \
    --vars-file $OUTPUT/vars.yml \
    -l $OUTPUT/releases_versions.yml \
    $OUTPUT/runtime-config.yml

  bosh -n update-runtime-config \
    --vars-store $OUTPUT/store.yml \
    --vars-file $OUTPUT/vars.yml \
    -l $OUTPUT/releases_versions.yml \
    $OUTPUT/runtime-config.yml
}

trap "sanitize_store && commit_config" EXIT

generate_configs
authenticate_director
upload_releases
update_runtime_config
sanitize_store
