#!/usr/bin/env bash
set -euo pipefail

: "${SCW_SECRET_KEY:?Missing SCW_SECRET_KEY}"
: "${SCW_EDGE_PIPELINE_ID:?Missing SCW_EDGE_PIPELINE_ID}"

api_url="https://api.scaleway.com/edge-services/v1beta1/purge-requests"

payload=$(jq -n --arg pipeline_id "$SCW_EDGE_PIPELINE_ID" \
  '{pipeline_id: $pipeline_id, assets: ["/versions/latest.json"]}')

response=$(curl --fail-with-body --silent --show-error \
  --connect-timeout 10 --max-time 30 \
  -X POST "$api_url" \
  -H "X-Auth-Token: $SCW_SECRET_KEY" \
  -H 'Content-Type: application/json' \
  --data "$payload")

purge_id=$(jq -er '.id | select(type == "string" and length > 0)' <<< "$response")

echo "Created CDN purge request: $purge_id"

for ((attempt = 1; attempt <= 60; attempt++)); do
  status=$(jq -er '.status' <<< "$response")
  case "$status" in
    done)
      echo "CDN cache purged for /versions/latest.json"
      exit 0
      ;;
    pending)
      if ((attempt == 60)); then
        break
      fi
      sleep 2
      response=$(curl --fail-with-body --silent --show-error \
        --connect-timeout 10 --max-time 30 \
        -H "X-Auth-Token: $SCW_SECRET_KEY" \
        "$api_url/$purge_id")
      ;;
    *)
      echo "CDN purge failed with status: $status" >&2
      exit 1
      ;;
  esac
done

echo "Timed out waiting for CDN purge: $purge_id" >&2
exit 1
