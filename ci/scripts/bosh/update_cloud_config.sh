#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

function update_cloud_config() {
  bosh -n update-cloud-config $OUTPUT/cloud-config.yml \
    --vars-file=$OUTPUT/vars.yml \
    -v vm_disk_type=thick
}

generate_configs
authenticate_director
update_cloud_config
