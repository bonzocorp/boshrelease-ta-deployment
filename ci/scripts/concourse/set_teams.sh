#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh


function get_all_users_for(){
  local url=/v2/organizations/$1/users

  while [ "$url" != "null" ]; do
    response=$(cf curl $url)
    users="$( echo $response | jq -r '.resources[] | .entity.username ')"
    url=$( echo $response| jq -r '.next_url')
  done

  echo $users
}

function authenticate_concourse(){
  fly -t concourse login -k -u $CONCOURSE_USERNAME -p $CONCOURSE_PASSWORD -c $CONCOURSE_TARGET
}

function set_team_for(){
  local org=$1
  local user=$2

  log "Adding user: $user to team: $org"

  fly -t concourse set-team \
    --non-interactive \
    --team-name $org \
    --cf-user $user \
    --cf-org $org \
    --cf-space $org:dev > /dev/null
}

check_if_exists "CF_API_URI is empty" $CF_API_URI
check_if_exists "CF_USER is empty" $CF_USER
check_if_exists "CF_PASSWORD is empty" $CF_PASSWORD
check_if_exists "ORGS_LIST_FILE is empty" $ORGS_LIST_FILE

cf_options=""
if [[ $CF_SKIP_SSL_VALIDATION == true ]]; then
  cf_options+=" --skip-ssl-validation"
fi

cf api --skip-ssl-validation "$CF_API_URI" $cf_options
cf auth "$CF_USER" "$CF_PASSWORD"
cf target -o "${CF_ORG:-system}" -s "${CF_SPACE:-system}"

authenticate_concourse

while read org; do
  org_guid="$(cf org --guid $org)"
  users=$(get_all_users_for $org_guid)

  for user in $users; do
    set_team_for $org $user
  done
done <$ORGS_LIST_FILE
