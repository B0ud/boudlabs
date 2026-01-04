# Configuration du Pare-feu Local (IPTables)

Ce document détaille la mise en place d'un pare-feu local robuste sur l'hôte Proxmox (Debian) pour compléter le firewall réseau d'OVH.

L'objectif est de :
1. Sécuriser le trafic IPv4 (NAT, Filtrage).
2. **Bloquer totalement le trafic IPv6** (Kill Switch) pour éviter les fuites, le firewall OVH ne filtrant que l'IPv4.

## 1. Script de Configuration

Créez le script `/root/firewall.sh` avec le contenu suivant. 

> [!NOTE]
> Adaptez les variables `PUB_IF` (interface publique) et `VM_IF` (interface bridge/privée) selon votre configuration.

```bash
#!/bin/bash

# ====================================================
# CONFIGURATION
# ====================================================
PUB_IF="vmbr0"           # Interface publique (Pont vers Internet)
VM_IF="vmbr1"            # Interface privée des VMs
WG_IF="wg0"              # Interface WireGuard
WG_PORT="51820"          # Port UDP WireGuard
VM_NET="192.168.50.0/24" # Sous-réseau des VMs
WG_NET="10.0.100.0/24"   # Sous-réseau VPN

# [MODIF CRITIQUE] ACTIVATION DU ROUTAGE NOYAU
# Sans ça, les règles FORWARD ne servent à rien !
echo 1 > /proc/sys/net/ipv4/ip_forward

# ====================================================
# 1. NETTOYAGE (RAZ)
# ====================================================
# IPv4
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# IPv6
ip6tables -F
ip6tables -X
ip6tables -t nat -F
ip6tables -t mangle -F

# ====================================================
# 2. POLITIQUES PAR DÉFAUT
# ====================================================
# IPv4
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# IPv6 : [MODIF] ON AUTORISE LA SORTIE
# On bloque tout ce qui rentre (pas de serveurs exposés)
# Mais on autorise le serveur à sortir (pour curl, apt update, etc.)
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT ACCEPT 

# ====================================================
# 3. EXCEPTION SYSTÈME (Localhost)
# ====================================================
iptables -A INPUT -i lo -j ACCEPT
ip6tables -A INPUT -i lo -j ACCEPT
# Pas besoin de règle OUTPUT lo car policy est ACCEPT, mais on peut laisser pour la forme
ip6tables -A OUTPUT -o lo -j ACCEPT

# ====================================================
# 4. RÈGLES IPv4 - ACCÈS PUBLIC
# ====================================================
# Connexions établies
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# [MODIF] IPv6 : On autorise le retour des paquets (pour que curl reçoive la réponse)
ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Autoriser le Ping (ICMP)
iptables -A INPUT -p icmp -j ACCEPT
# [MODIF] Ping IPv6 (Optionnel mais recommandé pour le debug réseau)
ip6tables -A INPUT -p ipv6-icmp -j ACCEPT

# Autoriser WireGuard
iptables -A INPUT -p udp --dport $WG_PORT -j ACCEPT

# Autoriser SSH
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# ====================================================
# 5. RÈGLES IPv4 - ROUTAGE & NAT (VMs/VPN)
# ====================================================

# A. Confiance VPN
iptables -A INPUT -i $WG_IF -j ACCEPT

# B. Communication VPN <-> VMs
iptables -A FORWARD -i $WG_IF -o $VM_IF -j ACCEPT
iptables -A FORWARD -i $VM_IF -o $WG_IF -j ACCEPT

# C. Accès Internet pour les VMs (NAT)
# Forwarding
iptables -A FORWARD -i $VM_IF -o $PUB_IF -j ACCEPT
iptables -A FORWARD -i $PUB_IF -o $VM_IF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# Masquerade (NAT)
iptables -t nat -A POSTROUTING -s $VM_NET -o $PUB_IF -j MASQUERADE

# D. Accès Internet pour le VPN (NAT)
iptables -A FORWARD -i $WG_IF -o $PUB_IF -j ACCEPT
iptables -A FORWARD -i $PUB_IF -o $WG_IF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -A POSTROUTING -s $WG_NET -o $PUB_IF -j MASQUERADE

echo "Firewall appliqué : IPv4 Routé + IPv6 Client Only (Sortie OK, Entrée Bloquée)."
```

Rendre le script exécutable :
```bash
chmod +x /root/firewall.sh
```

## 2. Test Sécurisé (Filet de Sécurité)

Lorsque vous appliquez des règles de firewall à distance, il y a un risque de s'enfermer dehors. Utilisez cette commande "saut de la mort" : elle applique les règles, attend 300 secondes, et si vous ne l'arrêtez pas (parce que vous avez perdu la connexion), elle remet tout à zéro (ACCEPT ALL).

```bash
/root/firewall.sh && echo "OK. Si tout marche, FAIS CTRL+C. Sinon attends 300s." && sleep 300 && iptables -P INPUT ACCEPT && iptables -F && ip6tables -P INPUT ACCEPT
```

*   **Si vous avez toujours accès** : Faites `CTRL+C` immédiatement pour conserver les règles.
*   **Si vous perdez l'accès** : Attendez 5 minutes, le firewall se désactivera tout seul.

## 3. Persistance des Règles

Une fois satisfait, installez `iptables-persistent` pour sauvegarder les règles au redémarrage.

```bash
apt update && apt install iptables-persistent netfilter-persistent -y
```

**Sauvegarder l'état actuel :**
```bash
netfilter-persistent save
```
*Cela écrit dans `/etc/iptables/rules.v4` et `/etc/iptables/rules.v6`.*

> [!IMPORTANT]
> `netfilter-persistent save` ne sauve que ce qui est **actuellement** chargé en mémoire. Si vous modifiez `firewall.sh`, vous devez le ré-exécuter puis refaire un `save`.

## 4. Vérification et Maintenance

**Voir les règles de FILTRAGE IPv4 (Sécurité) :**
```bash
iptables -L -n -v
```

```bash
cat /etc/iptables/rules.v4
```

**Voir les règles de NAT IPv4 (Internet des VMs) :**
```bash
iptables -t nat -L -n -v
```

**Vérifier le blocage IPv6 :**
```bash
ip6tables -L -n -v
```
Vous devriez voir `Chain INPUT (policy DROP)` et très peu de trafic autorisé (seulement loopback).