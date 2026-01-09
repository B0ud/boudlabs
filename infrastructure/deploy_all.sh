#!/bin/bash
set -e # Arrête le script dès qu'il y a une erreur

echo "🏗️  PHASE 1 : Infrastructure (OpenTofu)..."
cd infrastructure/provisioning
tofu apply -auto-approve

# --- RÉCUPÉRATION DES DONNÉES ---
echo "📥 Récupération des IPs..."
LB_IP=$(tofu output -raw haproxy_ip)
# On récupère la liste des workers au format JSON compact (ex: ["10.0.0.1","10.0.0.2"])
WORKERS_JSON=$(tofu output -json k8s_worker_ips)

echo "   -> HAProxy IP : $LB_IP"
echo "   -> Workers    : $WORKERS_JSON"

# --- PAUSE TECHNIQUE ---
# Souvent nécessaire car même si la VM est créée, le service SSH peut mettre 10-30s à démarrer
echo "💤 Attente de 30s pour le démarrage SSH..."
sleep 30

echo "⚙️  PHASE 2 : Configuration (Ansible)..."
cd ../configuration

# On lance Ansible en injectant les variables dynamiquement !
# Plus besoin de modifier les fichiers YAML à la main.
ansible-playbook -i "$LB_IP," deploy_haproxy.yml \
  --user root \
  --extra-vars "{\"k8s_worker_ips\": $WORKERS_JSON}"

echo "✅ Déploiement terminé avec succès !"