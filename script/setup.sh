#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
# --- Normalisation des scripts pour éviter les erreurs CRLF ---
find /vagrant/script -type f -name "*.sh" -exec dos2unix {} \; || true
set -x

echo "🧰 Préparation du système..."
sudo apt-get update -y
sudo apt-get install -yq curl git vim net-tools apt-transport-https ca-certificates gnupg lsb-release jq dos2unix unzip

# --- Installation Docker ---
echo "🐳 Installation de Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker vagrant
sudo systemctl enable docker
sudo systemctl start docker

# --- Installation kubectl ---
echo "⚙️ Installation de kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# --- Installation K3d ---
echo "🚀 Installation de K3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
k3d version

# --- Création du cluster ---
echo "🌐 Création du cluster K3d..."
k3d cluster create argocd-cluster --api-port 6550 -p "9090:80@loadbalancer" -p "30088:30088@loadbalancer" --agents 1

# --- Installation ArgoCD ---
echo "🧩 Installation de ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Attente du déploiement du serveur ArgoCD..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd || true

ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d || echo "inconnu")
echo "🔑 Mot de passe admin ArgoCD: $ARGO_PWD"

# --- Déploiement de ton app via ArgoCD ---
echo "🚀 Déploiement de ton application..."
dos2unix /vagrant/manifests/app.yaml
kubectl apply -f /vagrant/manifests/app.yaml

# --- Configuration du kubeconfig propre et persistant ---
echo "🗂️ Configuration du kubeconfig..."
sudo mkdir -p /home/vagrant/.kube
sudo k3d kubeconfig get argocd-cluster > /home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube
echo 'export KUBECONFIG=/home/vagrant/.kube/config' | sudo tee -a /home/vagrant/.bashrc
export KUBECONFIG=/home/vagrant/.kube/config
kubectl config use-context k3d-argocd-cluster || true

# --- Installation de ngrok ---
echo "🌍 Installation de ngrok..."
curl -s https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip -o ngrok.zip
unzip -o ngrok.zip
sudo mv ngrok /usr/local/bin/ngrok
rm ngrok.zip

if [[ -n "${NGROK_AUTHTOKEN:-}" ]]; then
  echo "🔐 Ajout du token Ngrok..."
  ngrok authtoken "$NGROK_AUTHTOKEN"

else
  echo "⚠️ Aucun NGROK_AUTHTOKEN trouvé, ngrok fonctionnera en mode limité."
fi

# --- Lancement ngrok en arrière-plan ---
echo "🚦 Lancement de ngrok sur le port 9090..."
nohup ngrok http 9090 --log=stdout > /tmp/ngrok.log 2>&1 &
sleep 8

echo "🔎 Vérification du tunnel Ngrok..."
cat /tmp/ngrok.log | grep -m1 "url=" || echo "⚠️ Aucun tunnel détecté dans les logs."
NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[]?.public_url' | grep https || true)

if [[ -n "$NGROK_URL" ]]; then
  echo "🌍 Tunnel ngrok actif : $NGROK_URL"
else
  echo "⚠️ Ngrok n'a pas démarré correctement."
fi

# --- Création du webhook GitHub ---
echo "🔗 Création du webhook GitHub..."
export NGROK_URL
bash /vagrant/script/github_webhook.sh || echo "⚠️ Impossible de créer le webhook"

# --- Vérification finale ---
echo "⏳ Attente de la synchronisation ArgoCD..."
sleep 30

echo "✅ [SETUP TERMINÉ]"
echo "🧠 ArgoCD : http://localhost:9090"
echo "   ➜ Identifiant : admin"
echo "   ➜ Mot de passe : $ARGO_PWD"
echo "🌍 Application : http://localhost:30088"
echo "🔗 Tunnel public : $NGROK_URL"
