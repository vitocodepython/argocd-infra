#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo " Préparation du système..."
sudo apt-get update -y
sudo apt-get install -yq curl git vim net-tools apt-transport-https ca-certificates gnupg lsb-release jq dos2unix unzip screen

# --- Normalisation CRLF ---
find /vagrant/script -type f -name "*.sh" -exec dos2unix {} \; || true
set -x

# --- Docker ---
echo " Installation de Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker vagrant
sudo systemctl enable docker
sudo systemctl start docker

# --- kubectl ---
echo " Installation de kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# --- K3d ---
echo " Installation de K3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# --- Création du cluster avec mémoire stable ---
echo " Création du cluster K3d..."
k3d cluster delete argocd-cluster || true
k3d cluster create argocd-cluster \
  --api-port 6550 \
  -p "9090:32080@loadbalancer" \
  -p "30088:30088@loadbalancer" \
  --agents 1 \
  --k3s-arg "--kubelet-arg=eviction-hard=imagefs.available<1%,memory.available<100Mi,nodefs.available<1%"@agent:0 \
  --k3s-arg "--kubelet-arg=system-reserved=memory=200Mi"@agent:0

# --- kubeconfig ---
mkdir -p /home/vagrant/.kube
k3d kubeconfig get argocd-cluster > /home/vagrant/.kube/config
export KUBECONFIG=/home/vagrant/.kube/config
sudo chown -R vagrant:vagrant /home/vagrant/.kube
echo 'export KUBECONFIG=/home/vagrant/.kube/config' >> /home/vagrant/.bashrc

# --- ArgoCD ---
echo " Installation de ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo " Attente du déploiement d'ArgoCD..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd || true

# --- Patch du service ---
echo "  Configuration du service ArgoCD..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort","ports":[{"port":80,"nodePort":32080},{"port":443,"nodePort":32514}]}}'

# --- Mot de passe ArgoCD ---
ARGO_PASS=$(kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode)
echo " Mot de passe admin ArgoCD: $ARGO_PASS"

# --- Déploiement automatique de vito-app ---
echo " Déploiement automatique de vito-app..."
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vito-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/vitocodepython/argocd-infra.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo "⏳ Attente du déploiement de vito-app..."
sleep 30
kubectl get pods -n default

# --- Vérification finale ---
ARGO_STATUS=$(kubectl get pods -n argocd | grep argocd-server | awk '{print $3}')
APP_STATUS=$(kubectl get pods -n default | grep vito-app | awk '{print $3}')

echo "------------------------------------------"
echo " [INSTALLATION TERMINÉE AVEC SUCCÈS]"
echo " ArgoCD : http://localhost:9090"
echo " Identifiant : admin"
echo " Mot de passe : $ARGO_PASS"
echo " ArgoCD Status : $ARGO_STATUS"
echo " Application : http://localhost:30088"
echo " App Status : $APP_STATUS"
echo "------------------------------------------"
