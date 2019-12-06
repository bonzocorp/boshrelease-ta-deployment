#!/bin/bash

set -e
set -x

url=$(cat metadata/atc-external-url)
team=$(cat metadata/build-team-name)
pipeline=$(cat metadata/build-pipeline-name)
job=$(cat metadata/build-job-name)
build=$(cat metadata/build-name)

for release in *-boshrelease ; do
  current=$(cat $release/version)
  latest=$(cat $release-latest/version)

  current="${current/\#*/}"
  latest="${latest/\#*/}"

cat <<EOT >> output/boshrelease_version_notification
New boshrelease ${release} v${latest} for ${DEPLOYMENT_NAME} is available.
Currently running v${current}
EOT

done


cat <<EOT >> output/boshrelease_version_notification
<${url}/teams/${team}/pipelines/${pipeline} |Go to pipeline>
EOT


exit 0
