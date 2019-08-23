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

function deploy() {
  local stemcell_version=""
  local bosh_args=""
  local bosh_action="deploy"

  for operation_file in $BOSH_OPERATIONS ;do
    bosh_args="$bosh_args -o $operation_file"
  done

  if [[ ! -z "${BOSH_SKIP_DRAIN}" ]] ; then
    bosh_args="$bosh_args --skip-drain=$BOSH_SKIP_DRAIN"
  fi

  if [[ "${BOSH_RECREATE,,}" == "true" ]] ; then
    bosh_args="$bosh_args --recreate"
  fi

  if [[ "${BOSH_NO_REDACT,,}" == "true" && "${BOSH_CREATE_ENV,,}" != "true" ]] ; then
    bosh_args="$bosh_args --no-redact"
  fi

  if [[ "${BOSH_DRY_RUN,,}" == "true"   && "${BOSH_CREATE_ENV,,}" != "true" ]] ; then
    bosh_args="$bosh_args --dry-run"
  fi

  if [[ "${BOSH_CREATE_ENV,,}" == "true" ]] ; then
    check_if_exists "STATE_FILE can not be empty when using create-env" $STATE_FILE
    bosh_action="create-env"
    bosh_args="$bosh_args --state=$STATE_FILE"
    cp $MANIFEST_FILE manifest.yml
    MANIFEST_FILE=manifest.yml
  fi

  for release in $(ls -d *-boshrelease); do
    release_name=${release%"-boshrelease"}
    echo "${release_name}_version: $(cat $release/version)" >> $OUTPUT/releases_versions.yml
  done

  if [[ ! -f $OUTPUT/releases_versions.yml ]]; then
    get_current_releases_versions > $OUTPUT/releases_versions.yml
  fi

  if [[ -f stemcell/version ]]; then
    stemcell_version="$(cat stemcell/version)"
  else
    stemcell_version="$(get_current_stemcell)"
  fi

  bosh $bosh_action $MANIFEST_FILE \
    --vars-store $OUTPUT/store.yml \
    -l $OUTPUT/releases_versions.yml \
    -l $OUTPUT/vars.yml \
    -v deployment_name=$BOSH_DEPLOYMENT \
    -v stemcell_version="'$stemcell_version'" \
      $bosh_args -n
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

function run_errand(){
  bosh run-errand $1
}

function sanitize_store(){
  check_vault_unseal
  yaml2vault -f $OUTPUT/store.yml -p $YAML2VAULT_PREFIX > ${OUTPUT}/sanitized_store.yml
}

function commit_config(){
  BUILD_NAME=$(cat metadata/build-name)
  BUILD_JOB_NAME=$(cat metadata/build-job-name)
  BUILD_PIPELINE_NAME=$(cat metadata/build-pipeline-name)
  BUILD_TEAM_NAME=$(cat metadata/build-team-name)
  ATC_EXTERNAL_URL=$(cat metadata/atc-external-url)

  git clone config config-mod

  if [[ -s ${STATE_FILE} ]]; then
    cp ${STATE_FILE} ${STATE_FILE/config/config-mod}
    git -C config-mod add ${STATE_FILE/config\//}
  fi

  if [[ -s ${OUTPUT}/sanitized_store.yml ]]; then
    cp ${OUTPUT}/sanitized_store.yml ${STORE_FILE/config/config-mod}
    git -C config-mod add ${STORE_FILE/config\//}
  fi


  pushd config-mod > /dev/null

    git config --global user.name $GIT_USERNAME
    git config --global user.email $GIT_EMAIL

    if ! git diff-index --quiet HEAD --; then
      git commit -m "Updates files for deployment: https://$ATC_EXTERNAL_URL/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME "
    fi
  popd > /dev/null
}

function upload_releases(){
  for release in $(ls -d *-boshrelease); do
    upload_release $release
  done
}

function run_errands(){
  for errand in $BOSH_ERRANDS; do
    run_errand $errand
  done
}

trap "sanitize_store && commit_config" EXIT

generate_configs
authenticate_director
if [[ "${BOSH_CREATE_ENV,,}" != "true" ]] ; then
  upload_stemcell
  upload_releases
fi
deploy
sanitize_store
run_errands
