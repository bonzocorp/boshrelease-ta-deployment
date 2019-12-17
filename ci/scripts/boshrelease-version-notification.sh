#!/bin/bash

set -e
set -x

url=$(cat metadata/atc-external-url)
team=$(cat metadata/build-team-name)
pipeline=$(cat metadata/build-pipeline-name)
job=$(cat metadata/build-job-name)
build=$(cat metadata/build-name)

notification=output/boshrelease_version_notification
pending_upgrades=output/pending_upgrades

echo "${DEPLOYMENT_NAME} boshreleases status notification:" >> $notification
for release in *-boshrelease ; do
  current=$(cat $release/version)
  latest=$(cat $release-latest/version)

  current="${current/\#*/}"
  latest="${latest/\#*/}"

  if [[ $current  == $latest ]]; then
    echo "Boshrelease \`${release}\` up to date at *v${latest}*." >> $notification
  else
    echo "New \`${release}\` *v${latest}* is available. Currently running *v${current}*" >> $notification
    echo "${release},${current},${latest}" 																											   >> $pending_upgrades
  fi
done

echo "<${url}/teams/${team}/pipelines/${pipeline} |Go to pipeline>" >> $notification

exit 0
