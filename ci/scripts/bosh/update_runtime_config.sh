#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

function update_runtime_config() {
  bosh -n update-runtime-config $OUTPUT/runtime-config.yml
}

trap "sanitize_store && commit_config" EXIT

generate_configs
authenticate_director
update_runtime_config
sanitize_store
