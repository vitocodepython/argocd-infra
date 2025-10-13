#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
set -x

echo "Préparation du système"
sudo apt-get update -y
sudo apt-mark hold grub-efi-amd64 grub-efi-amd64-bin grub2-common linux-image-generic linux-headers-generic linux-firmware openssh-server cloud-init snapd

echo "Installation des dépendances"
sudo apt-get install -yq curl git vim net-tools apt-transport-https ca-certificates gnupg lsb-release

echo "Installation de Docker"
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker vagrant
sudo systemctl enable docker
sudo systemctl start docker

echo "Installation de kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

echo "Installation de k3d"
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
k3d version || echo " Erreur lors de l'installation de k3d"

echo "Installation et configuration d'ArgoCD"
k3d cluster create argocd-cluster --api-port 6550 -p "8080:80@loadbalancer" -p "8888:8888@loadbalancer" --agents 1

kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo " Attente de la disponibilité du serveur ArgoCD"
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

# Récupération du mot de passe admin ArgoCD
ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "inconnu")

# Exposition automatique d'ArgoCD sur le port 9090
nohup kubectl port-forward svc/argocd-server -n argocd --address 0.0.0.0 9090:80 > /dev/null 2>&1 &
kubectl apply -f /vagrant/manifests/app.yaml


echo " [SETUP TERMINÉ]"
echo " ArgoCD accessible à : http://192.168.56.110:9090"
echo " Identifiant : admin"
echo " Mot de passe : $ARGO_PWD"

bash /vagrant/script/github_webhook.sh || echo "Impossible de créer le webhook GitHub"
