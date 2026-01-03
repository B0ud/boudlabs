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
   - Création de la VM
   - Configuration (MachineConfig)
   - Bootstrap du cluster
