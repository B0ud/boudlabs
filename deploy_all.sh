#!/bin/bash
set -e # Arrête le script en cas d'erreur

# --- CONFIGURATION ---
# Remplace par l'IP de ton Proxmox
PROXMOX_HOST="root@192.168.50.1"
REMOTE_DIR="/root/ansible-deployment"

# Couleurs pour le style
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🏗️  PHASE 1 : Infrastructure (OpenTofu Local)...${NC}"

# On va dans le dossier Tofu
cd infrastructure/provisioning

# On lance Tofu (l'exécutable Windows tofu.exe est compatible Git Bash)
tofu apply -auto-approve

# --- RÉCUPÉRATION DES VARIABLES ---
echo -e "${GREEN}📥 Récupération des IPs...${NC}"

# On récupère l'IP du Load Balancer (sans les guillemets)
LB_IP=$(tofu output -raw haproxy_ip)

# On récupère la liste JSON des workers (ex: ["10.0.0.1", "10.0.0.2"])
# L'option -json est importante pour le format
WORKERS_JSON=$(tofu output -json worker_ips)

echo "   -> HAProxy IP : $LB_IP"
echo "   -> Workers    : $WORKERS_JSON"

echo -e "${CYAN}💤 Attente de 15s (Démarrage SSH VM)...${NC}"
sleep 15

# --- PHASE 2 : TRANSFERT VERS PROXMOX ---
echo -e "${CYAN}🚀 Copie des fichiers vers Proxmox...${NC}"
cd .. # Infrastructure
pwd

# 1. Nettoyer et recréer le dossier distant
ssh $PROXMOX_HOST "rm -rf $REMOTE_DIR/configuration && mkdir -p $REMOTE_DIR"

# 2. Copier le dossier 'configuration' (Ansible) vers Proxmox
scp -r configuration $PROXMOX_HOST:$REMOTE_DIR/

# --- PHASE 3 : EXÉCUTION DISTANTE ---
echo -e "${CYAN}🔑 Trusting HAProxy Host Key on Proxmox...${NC}"
# On supprime l'ancienne clé (si elle existe) et on scanne la nouvelle pour l'ajouter aux known_hosts
ssh $PROXMOX_HOST "ssh-keygen -f ~/.ssh/known_hosts -R $LB_IP ; ssh-keyscan -H $LB_IP >> ~/.ssh/known_hosts"

echo -e "${CYAN}⚙️  Lancement d'Ansible SUR Proxmox...${NC}"

# On construit la commande à envoyer via SSH.
# Attention aux échappements (\) pour que le JSON arrive intact.
SSH_CMD="cd $REMOTE_DIR/configuration && \
ansible-playbook -i inventory.ini deploy_haproxy.yml \
--extra-vars '{\"worker_ips\": $WORKERS_JSON}'"

# Exécution
ssh $PROXMOX_HOST "$SSH_CMD"

echo -e "${GREEN}✅ Déploiement terminé avec succès !${NC}"