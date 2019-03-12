#!/bin/bash

exec >&2
set -e

source pipeline/ci/scripts/common.sh

cat << EOF > query.json
{
  "query": {
    "range" : {
      "@timestamp" : {
        "gte" : "now-$INTERVAL/m",
        "lt" : "now/m"
      }
    }
  }
}
EOF

today=`date +%Y.%m.%d`

hits=$(curl -s -d @query.json -X GET -H "Content-type: application/json" $ELASTICSEARCH_IP:$ELASTICSEARCH_PORT/$INDEX_PATTERN-$today/_search | jq -r '.hits.total')

echo "====> $hits in the last $INTERVAL"
if [[ "$hits" == "0" ]] ;then
  exit 1
fi
