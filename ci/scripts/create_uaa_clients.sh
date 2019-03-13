#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

function curl_uaa() {
  curl --fail \
    -w "%{http_code}" \
    -H "Authorization:Bearer $ACCESS_TOKEN" \
    -H "Accept:application/json" \
    -H "Content-Type:application/json" \
    --cacert $UAA_CA_CERT \
    "$@"
}

function create_uaa_client() {
  local JSON="$1"

  # List all the variables to fail before commands are run
  local CLIENT_ID="$( echo "$JSON" | jq -r '.client_id' )"
  local CLIENT_SECRET="$( echo "$JSON" | jq -r '.client_secret' )"
  local AUTO_APPROVE="$( echo "$JSON" | jq -r '.autoapprove // false' )"
  local SCOPE="$( echo "$JSON" | jq -r '.scope // []' )"
  local AUTHORITIES="$( echo "$JSON" | jq -r '.authorities // []' )"
  local RESOURCE_IDS="$( echo "$JSON" | jq -r '.resource_ids // []' )"
  local AUTHORIZED_GRANT_TYPES="$( echo "$JSON" | jq -r '.authorized_grant_types // []' )"
  local ACCESS_TOKEN_VALIDITY="$( echo "$JSON" | jq -r '.access_token_validity // 41300' )"
  local REDIRECT_URI="$( echo "$JSON" | jq -r '.redirect_uri // []' )"


  local ACCESS_TOKEN=$(
    curl  -s -D - -d "" \
    --cacert $UAA_CA_CERT \
    -u $UAA_ADMIN_CLIENT_ID:$UAA_ADMIN_CLIENT_SECRET \
    -X POST "https://${UAA_URL}/oauth/token?grant_type=client_credentials&response_type=token&redirect_uri=http://dummy.com" \
    | sed -n 's/.*access_token":"\([^"]*\).*/\1/p'
  )

  if [[ -z "$ACCESS_TOKEN" ]]; then
    error "Could not fetch token"
    echo $( curl -D - -d "" \
    --cacert $UAA_CA_CERT \
    -u $UAA_ADMIN_CLIENT_ID:$UAA_ADMIN_CLIENT_SECRET \
    -X POST "https://${UAA_URL}/oauth/token?grant_type=client_credentials&response_type=token&redirect_uri=http://dummy.com" )
    exit 1
  fi


  log "Checking if $CLIENT_ID client exists"
  local CLIENT_EXISTS_RESPONSE=$(
    curl_uaa -s -S -o /dev/null \
    -X GET "https://${UAA_URL}/oauth/clients/${CLIENT_ID}"
  )

  # Since we cannot update client_id and client_secret without keeping track of previous state we delete the old client, and recreate it.
  if [ $CLIENT_EXISTS_RESPONSE != "404" ]; then
    log "Deleting old OAuth2 client: ${CLIENT_ID}"
    local DELETE_CLIENT_RESPONSE=$(
      curl_uaa -X DELETE "https://${UAA_URL}/oauth/clients/${CLIENT_ID}"
    )
  fi

  log "Creating new OAuth2 client: ${CLIENT_ID}"
  local CREATE_CLIENT_RESPONSE=$(
    curl_uaa \
    -d "{
      \"client_id\" : \"${CLIENT_ID}\",
      \"client_secret\" : \"${CLIENT_SECRET}\",
      \"autoapprove\" : ${AUTO_APPROVE},
      \"scope\" : ${SCOPE},
      \"authorities\" : ${AUTHORITIES},
      \"resource_ids\" : ${RESOURCE_IDS},
      \"authorized_grant_types\" : ${AUTHORIZED_GRANT_TYPES},
      \"access_token_validity\": ${ACCESS_TOKEN_VALIDITY:-43200},
      \"redirect_uri\": ${REDIRECT_URI}
    }" \
    -X POST "https://${UAA_URL}/oauth/clients"
  )
}

function create_uaa_clients() {
  check_if_file_exists $OUTPUT/uaa_clients.yml
  check_if_file_exists $OUTPUT/vars.yml

  export VAULT_SKIP_VERIFY=true

  bosh int $OUTPUT/uaa_clients.yml -l $OUTPUT/vars.yml |
    spruce json |
    jq -rc '.servers[]' |
    while read -r server_json; do
      export UAA_SERVER_NAME=$( echo "$server_json" | jq -r '.name' )
      export UAA_URL=$( echo "$server_json" | jq -r '.url' )
      export UAA_CA_CERT=/tmp/$UAA_URL.pem
      jq -r '.ca_cert' <<< $server_json > $UAA_CA_CERT
      export UAA_ADMIN_CLIENT_ID=$( echo "$server_json" | jq -r '.admin_client_id' )
      export UAA_ADMIN_CLIENT_SECRET=$( echo "$server_json" | jq -r '.admin_client_secret' )

      check_if_exists "\$UAA_URL not defined for $UAA_SERVER_NAME" $UAA_URL
      check_if_exists "\$UAA_ADMIN_CLIENT_ID not defined for $UAA_SERVER_NAME" $UAA_ADMIN_CLIENT_ID
      check_if_exists "\$UAA_ADMIN_CLIENT_SECRET not defined for $UAA_SERVER_NAME" $UAA_ADMIN_CLIENT_SECRET
      check_if_exists "\$UAA_CA_CERT not defined for $UAA_SERVER_NAME" $UAA_CA_CERT

      log "Creating uaa clients for $UAA_URL"
      echo "$server_json" |
        jq -rc '.clients[]' |
        while read client_json; do
          log "Creating uaa client $( echo "$client_json" | jq -r '.client_id' )"
          create_uaa_client "$client_json"
        done
    done
}

load_custom_ca_certs
generate_configs
create_uaa_clients
