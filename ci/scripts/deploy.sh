#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

function get_current_releases_versions() {
  local deployment_response=$(bosh deployment -d $BOSH_DEPLOYMENT --json | jq '.Tables[0].Rows[0].release_s' -r )
  sed "s/\//_version: /g" <<<$deployment_response
}

function get_current_stemcell() {
  local deployment_response=$(bosh deployment -d $BOSH_DEPLOYMENT --json | jq '.Tables[0].Rows[0].stemcell_s' -r )
  sed "s/.*\///g" <<<$deployment_response
}


function run_bosh(){
  local bosh_action=$1
  shift
  local bosh_args=$@
  local bosh_ops=""

  for operation_file in $(cat $OUTPUT/ops_files.yml | jq ".ops_files[] " -r) ;do
    bosh_ops="$bosh_ops -o $operation_file"
  done

  generate_releases_version_file

  if [[ -f stemcell/version ]]; then
    stemcell_version="$(cat stemcell/version)"
  else
    stemcell_version="$(get_current_stemcell)"
  fi

  bosh $bosh_action manifest.yml\
    --vars-store $OUTPUT/store.yml \
    -l $OUTPUT/releases_versions.yml \
    -l $OUTPUT/vars.yml \
    -v deployment_name=$BOSH_DEPLOYMENT \
    -v stemcell_version="'$stemcell_version'" \
      $bosh_ops \
      $bosh_args -n
}
function deploy() {
  local stemcell_version=""
  local bosh_args=""
  local bosh_action="deploy"

  # Creates a copy of the targeted manifest in the current dir
  cp $MANIFEST_FILE manifest.yml

  if [[ ! -z "${BOSH_SKIP_DRAIN}" ]] ; then
    bosh_args="$bosh_args --skip-drain=$BOSH_SKIP_DRAIN"
  fi

  if [[ "${BOSH_RECREATE,,}" == "true" ]] ; then
    bosh_args="$bosh_args --recreate"
  fi

  if [[ "${BOSH_FIX,,}" == "true" && "${BOSH_CREATE_ENV,,}" != "true" ]] ; then
    bosh_args="$bosh_args --fix"
  fi

  if [[ "${BOSH_NO_REDACT,,}" == "true" && "${BOSH_CREATE_ENV,,}" != "true" ]] ; then
    bosh_args="$bosh_args --no-redact"
  fi

  if [[ "${BOSH_DRY_RUN,,}" == "true"   && "${BOSH_CREATE_ENV,,}" != "true" ]] ; then
    bosh_args="$bosh_args --dry-run"
  fi

  if [[ "$BOSH_CREATE_ENV" == "true" ]] ; then
    check_if_exists "STATE_FILE can not be empty when using create-env" $STATE_FILE
    bosh_action="create-env"
    bosh_args="$bosh_args --state=$STATE_FILE"
  fi

  run_bosh interpolate > $OUTPUT/manifest.yml
  run_bosh $bosh_action $bosh_args
}

function upload_stemcell() {
  stemcell_path=`find ./stemcell -name *.tgz | sort | head -1`

  if [[ -n $stemcell_path ]]; then
    log "Uploading stemcell"
    bosh upload-stemcell $stemcell_path
  else
    log "No stemcell found... Skipping upload"
  fi
}

function upload_release() {
  release_path=`find ./$1 -name *.tgz | sort | head -1`

  if [[ -n $release_path ]]; then
    log "Uploading $1 release"
    bosh upload-release $release_path
  else
    log "No $1 release found... Skipping upload"
  fi
}

function upload_releases(){
  for release in $(ls -d *-boshrelease); do
    upload_release $release
  done
}

function run_errand(){
  bosh run-errand $1
}

function run_errands(){
  local bosh_errands=$(cat $OUTPUT/errands.yml | jq ".errands[] " -r)

  for errand in $bosh_errands; do
    run_errand $errand
  done
}

function update_secrets(){
  if [[ $? == 0 ]] ; then
    log "Deploy successful. Cleaning up secrets"
  else
    error "Deploy failed. Cleaning up secrets"
  fi

  sanitize_store && commit_config
}

trap "update_secrets" EXIT

generate_configs
if [[ "${BOSH_CREATE_ENV,,}" != "true" ]] ; then
  authenticate_director
  upload_stemcell
  upload_releases
fi
deploy
run_errands
