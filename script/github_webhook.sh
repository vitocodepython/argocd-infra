#!/usr/bin/env bash
set -euo pipefail

OWNER="vitocodepython"
REPO="app-ci-cd"  
WEBHOOK_URL="http://192.168.56.110:9090"
EVENTS='["push"]'

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo " Aucun GITHUB_TOKEN trouvé."
  echo "Pour activer la création automatique du webhook GitHub,"
  echo "exécute : export GITHUB_TOKEN=<votre_token>"
  echo "puis relance vagrant up"
  exit 0
fi

API="https://api.github.com/repos/${OWNER}/${REPO}/hooks"
AUTH="Authorization: Bearer ${GITHUB_TOKEN}"

payload=$(jq -nc \
  --arg url "$WEBHOOK_URL" \
  --argjson events "$EVENTS" \
  '{name:"web", active:true, events:$events, config:{url:$url, content_type:"json"}}')

existing_id=$(curl -fsSL -H "$AUTH" "$API" | jq -r --arg url "$WEBHOOK_URL" '.[] | select(.config.url==$url) | .id' | head -n1 || true)

if [[ -n "${existing_id:-}" ]]; then
  echo "Webhook existe déjà (#$existing_id)"
else
  echo "Création du webhook..."
  curl -fsSL -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$payload" "$API" >/dev/null
  echo " Webhook créé avec succès"
fi
