#!/usr/bin/env bash
# Update Docker Hub short description, Overview, and categories from deploy/docker-hub.md.
# Needs DOCKERHUB_USERNAME and DOCKERHUB_TOKEN (PAT: Read, Write, and Delete).
set -euo pipefail

if [[ -z "${DOCKERHUB_USERNAME:-}" || -z "${DOCKERHUB_TOKEN:-}" ]]; then
  echo "DOCKERHUB_USERNAME and DOCKERHUB_TOKEN are required" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
README="$ROOT/deploy/docker-hub.md"
SHORT="Self-hosted observability for OpenTelemetry traces, logs, and a service map"
NS="https://hub.docker.com/v2/namespaces/${DOCKERHUB_USERNAME}/repositories/rasat"
CATEGORIES='[{"name":"Monitoring & observability","slug":"monitoring-and-observability"},{"name":"Developer tools","slug":"developer-tools"}]'

BODY="$(jq -n \
  --arg description "$SHORT" \
  --rawfile full_description "$README" \
  '{description:$description, full_description:$full_description}')"

JWT="$(curl -fsS -X POST https://hub.docker.com/v2/users/login/ \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg u "$DOCKERHUB_USERNAME" --arg p "$DOCKERHUB_TOKEN" '{username:$u,password:$p}')" \
  | jq -r .token)"

if [[ -z "$JWT" || "$JWT" == "null" ]]; then
  echo "Docker Hub login did not return a token" >&2
  exit 1
fi

patch() {
  local url="$1"
  local auth="$2"
  local payload="$3"
  curl -sS -o /tmp/hub-overview.json -w '%{http_code}' -X PATCH "$url" \
    -H "Authorization: Bearer $auth" \
    -H 'Content-Type: application/json' \
    -d "$payload"
}

# Description lives on the repository resource. Categories are a sibling PATCH
# (sending them on the repository body is a no-op).
AUTH="$JWT"
CODE="$(patch "$NS" "$AUTH" "$BODY")"
if [[ "$CODE" != "200" && "$CODE" != "202" ]]; then
  AUTH="$DOCKERHUB_TOKEN"
  CODE="$(patch "$NS" "$AUTH" "$BODY")"
fi
if [[ "$CODE" != "200" && "$CODE" != "202" ]]; then
  echo "Hub overview PATCH failed (${CODE}). Token needs Read, Write, and Delete." >&2
  cat /tmp/hub-overview.json >&2 || true
  echo >&2
  exit 1
fi

CAT="$(patch "$NS/categories" "$AUTH" "$CATEGORIES")"
if [[ "$CAT" != "200" && "$CAT" != "202" ]]; then
  echo "Hub categories PATCH failed (${CAT})." >&2
  cat /tmp/hub-overview.json >&2 || true
  echo >&2
  exit 1
fi

echo "Updated Hub overview and categories"
