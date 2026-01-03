# Installation et Configuration de Proxmox VE

## 1. Pré-requis
- Un serveur dédié avec accès KVM/IPMI pour l'installation initiale.
- Image ISO de Proxmox VE (dernière version stable).

## 2. Installation
1. Booter sur l'ISO Proxmox VE.
2. Suivre l'installateur graphique.
   - **Target Harddisk**: Sélectionner le disque principal (RAID matériel ou ZFS software si plusieurs disques).
   - **Country/Timezone**: Configurer selon la location.
   - **Password/Email**: Définir un mot de passe root fort.
   - **Network Configuration**:
     - Management Interface: Choisir l'interface principale connecté au net.
     - Hostname: `pve.boudlabs.local` (exemple).
     - IP Address: L'IP publique du serveur.
     - Gateway/DNS: Fournis par l'hébergeur.

## 3. Configuration Post-Installation

### Mise à jour des dépôts (No-Subscription)
Si vous n'avez pas de souscription entreprise, modifiez les sources `apt`.

Fichier `/etc/apt/sources.list.d/pve-enterprise.list` :
```bash
# Commenter la ligne entreprise
# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise
```

Ajouter le dépôt "no-subscription" dans `/etc/apt/sources.list` :
```bash
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
```

Mise à jour du système :
```bash
apt update && apt dist-upgrade -y
```

### Configuration Réseau (Bridge)
Pour que les VMs (comme Talos) puissent avoir leur propre IP ou être derrière un NAT, on utilise généralement un Linux Bridge (`vmbr0`).

Vérifier `/etc/network/interfaces` :
```auto
auto lo
iface lo inet loopback

iface eno1 inet manual

auto vmbr0
iface vmbr0 inet static
    address <PUBLIC_IP>/24
    gateway <GATEWAY_IP>
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
```
*Note : Adaptez `eno1` et les IPs selon votre serveur.*



