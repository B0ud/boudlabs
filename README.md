# BoudLabs Dedicated Server Documentation

Ce dépôt documente l'installation et la configuration complète d'un serveur dédié hébergeant un cluster Kubernetes via **Talos Linux** sur un hyperviseur **Proxmox VE**.

## Architecture Cible

L'objectif est de sécuriser l'accès au serveur en n'exposant aucun port de management (SSH, Proxmox GUI, Talos API) sur internet public, à l'exception du port UDP de **WireGuard**.

- **Hyperviseur**: Proxmox VE
- **OS Kubernetes**: Talos Linux (virtualisé dans Proxmox)
- **Accès Sécurisé**: WireGuard (VPN)

## Table des Matières

1. [Installation et Configuration de Proxmox](./docs/proxmox.md)
   - Préparation hardware
   - Installation de l'OS
   - Configuration réseau (Linux Bridge)
   - [Sécurité Réseau (Firewall OVH)](./docs/ovh_firewall.md)
   - [Sécurité Locale (iptables / IPv6 Killswitch)](./docs/iptables.md)
   - [Personnalisation OS (Vim, etc.)](./docs/os_setup.md)
2. [Mise en place de WireGuard](./docs/wireguard.md)
   - Installation sur l'hôte Proxmox (pour l'accès d'urgence et management)
   - Configuration des pairs (Clients)
   - Règles de Pare-feu
3. [Déploiement de Talos Linux](./docs/talos.md)
   - [Mise à jour Cluster (Talos & K8s)](./docs/cluster_upgrades.md)
   - [Dépannage & Commandes utiles](./docs/talos_talhelper.md)
4. [Intégration IA / MCP (Model Context Protocol)](./docs/mcp_proxmox_integration.md)
   - [Intégration Proxmox](./docs/mcp_proxmox_integration.md)
   - [Intégration Kubernetes & Talos](./docs/mcp_k8s_talos_integration.md)

## Autres Ressources
- [Modèle de Configuration Talos](./docs/talos_template.md)
- [Déploiement Terraform (Infrastructure as Code)](./docs/terraform_proxmox.md)
  - Découpage modulaire : `main.tf` (ressources), `variables.tf`, `outputs.tf`, `providers.tf`.
- [GitOps avec FluxCD](./docs/gitops_flux.md)
