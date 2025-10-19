#!/bin/bash
set -euo pipefail

REPO="vitocodepython/argocd-infra"

echo " Récupération de l'URL Ngrok..."
NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[]?.public_url' | grep https || true)
WEBHOOK_URL="${NGROK_URL}/api/webhook"

if [[ -z "${NGROK_URL}" ]]; then
  echo " Impossible de récupérer l'URL Ngrok."
  exit 1
fi

echo " Ngrok détecté : ${WEBHOOK_URL}"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo " Aucun GITHUB_TOKEN défini — impossible de créer le webhook."
  exit 1
fi

echo " Création du webhook pour le repo : ${REPO}"

# Appel API GitHub
HTTP_CODE=$(curl -s -o /tmp/webhook_response.json -w "%{http_code}" \
  -X POST "https://api.github.com/repos/${REPO}/hooks" \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "{
    \"name\": \"web\",
    \"active\": true,
    \"events\": [\"push\"],
    \"config\": {
      \"url\": \"${WEBHOOK_URL}\",
      \"content_type\": \"json\"
    }
  }")

# Vérification du code de retour
if [[ "$HTTP_CODE" != "201" && "$HTTP_CODE" != "200" ]]; then
  echo " Erreur HTTP ${HTTP_CODE} lors de la création du webhook"
  echo " Réponse GitHub :"
  cat /tmp/webhook_response.json
  exit 1
fi

# Vérification du contenu JSON
if jq -e '.id' /tmp/webhook_response.json >/dev/null 2>&1; then
  echo " Webhook créé avec succès pour ${WEBHOOK_URL}"
else
  echo " Webhook non créé correctement. Contenu inattendu :"
  cat /tmp/webhook_response.json
  exit 1
fi

rm -f /tmp/webhook_response.json
