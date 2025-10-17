#!/usr/bin/env bash
set -euo pipefail

OWNER="vitocodepython"
REPO="app-ci-cd"
EVENTS='["push"]'

# --- Détection ngrok ---
NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[]?.public_url' | grep https || true)
if [[ -n "$NGROK_URL" ]]; then
  WEBHOOK_URL="${NGROK_URL}/api/webhook"
  echo " Ngrok détecté : $WEBHOOK_URL"
else
  WEBHOOK_URL="http://192.168.56.110:9090/api/webhook"
  echo " Ngrok non détecté, utilisation locale : $WEBHOOK_URL"
fi

# --- Vérification du token GitHub ---
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo " Aucun GITHUB_TOKEN trouvé."
  exit 0
fi

API="https://api.github.com/repos/${OWNER}/${REPO}/hooks"
AUTH="Authorization: Bearer ${GITHUB_TOKEN}"

payload=$(jq -nc --arg url "$WEBHOOK_URL" --argjson events "$EVENTS" \
  '{name:"web", active:true, events:$events, config:{url:$url, content_type:"json"}}')

existing_id=$(curl -fsSL -H "$AUTH" "$API" | jq -r --arg url "$WEBHOOK_URL" '.[] | select(.config.url==$url) | .id' | head -n1 || true)

if [[ -n "${existing_id:-}" ]]; then
  echo " Webhook déjà existant (#$existing_id)"
else
  echo " Création du webhook..."
  curl -fsSL -X POST -H "$AUTH" -H "Content-Type: application/json" -d "$payload" "$API" >/dev/null
  echo " Webhook créé avec succès"
fi
