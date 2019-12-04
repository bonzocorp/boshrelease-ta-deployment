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

function check_vault_unseal() {

  vault_fqdn=$(echo $VAULT_ADDR | cut -d "/" -f 3)

  while read ip; do
    seal_status_url="https://$ip/v1/sys/seal-status"
    seal_status_body="$(curl -k $seal_status_url)"
    seal_status_code="$(curl -k -s -o /dev/null -w "%{http_code}" $seal_status_url)"
    seal_status=$(echo $seal_status_body | jq '.sealed')

    if [[ $seal_status_code != "200" ]]; then
      echo "Vault is not responding"
      exit 1
    elif [[ $seal_status == "true" ]]; then
      echo "Vault IP $ip is sealed"
      exit 1
    fi
  done < <(dig +short $vault_fqdn)
}

function log() {
  green='\033[0;32m'
  reset='\033[0m'

  echo -e "${green}$1${reset}"
}

function error() {
  red='\033[0;31m'
  reset='\033[0m'

  echo -e "${red}$1${reset}"
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

function find_or_create() {
  for file in "$@"; do
    basedir=$(dirname "$file")
    mkdir -p $basedir
    if [[ ! -s "$file" ]] ; then
      echo -e "---\n{}" > $file
    fi
  done
}

function generate_configs(){
  log "Generating config files ..."

  find_or_create $VARS_FILE
  spruce merge $VARS_FILE 2>/dev/null > $OUTPUT/vars.yml

  if [[ ! -z "$UAA_CLIENTS_FILE" ]] ; then
    spruce merge $UAA_CLIENTS_FILE 2>/dev/null > $OUTPUT/uaa_clients.yml
  fi

  find_or_create $STORE_FILE
  spruce merge $STORE_FILE 2>/dev/null > $OUTPUT/store.yml

  find_or_create $CREDS_FILE
  if [[ ! -z "$CREDS_FILE" ]] ; then
    spruce merge $CREDS_FILE 2>/dev/null > $OUTPUT/creds.yml
  fi

  if [[ ! -z "$CLOUD_CONFIG_FILE" ]] ; then
    spruce merge $CLOUD_CONFIG_FILE 2>/dev/null > $OUTPUT/cloud-config.yml
  fi

  if [[ ! -z "$RUNTIME_CONFIG_FILE" ]] ; then
    spruce merge $RUNTIME_CONFIG_FILE 2>/dev/null > $OUTPUT/runtime-config.yml
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

function sanitize_store(){
  if [[ ! -z "$STORE_FILE" ]] ; then
    check_vault_unseal
    yaml2vault -f $OUTPUT/store.yml -p $YAML2VAULT_PREFIX > ${OUTPUT}/sanitized_store.yml
  fi
}

function commit_config(){
  BUILD_NAME=$(cat metadata/build-name)
  BUILD_JOB_NAME=$(cat metadata/build-job-name)
  BUILD_PIPELINE_NAME=$(cat metadata/build-pipeline-name)
  BUILD_TEAM_NAME=$(cat metadata/build-team-name)
  ATC_EXTERNAL_URL=$(cat metadata/atc-external-url)

  check_if_exists "GIT_USERNAME is not defined." $GIT_USERNAME
  check_if_exists "GIT_EMAIL is not defined." $GIT_EMAIL

  git clone config config-mod

  if [[ -s ${STATE_FILE} ]]; then
    cp ${STATE_FILE} ${STATE_FILE/config/config-mod}
    git -C config-mod add ${STATE_FILE/config\//}
  fi

  if [[ -s ${OUTPUT}/sanitized_store.yml ]]; then
    mkdir -p `dirname ${STORE_FILE/config/config-mod}`
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

  return 0
}
function generate_releases_version_file(){
  for release in $(ls -d *-boshrelease); do
    release_name=${release%"-boshrelease"}
    echo "${release_name}_version: $(cat $release/version)" >> $OUTPUT/releases_versions.yml
  done

  if [[ ! -f $OUTPUT/releases_versions.yml ]]; then
    get_current_releases_versions > $OUTPUT/releases_versions.yml
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

load_custom_ca_certs
