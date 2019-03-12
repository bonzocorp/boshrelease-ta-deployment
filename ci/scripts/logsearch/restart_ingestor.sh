#!/bin/bash

source pipeline/ci/scripts/common.sh

function restart_ingestor(){
  bosh -d logsearch restart --force ingestor
}

generate_configs
authenticate_director
restart_ingestor
