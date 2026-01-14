# Guide de Configuration : Accès Public (Proxmox Cloud)

Ce guide est adapté à votre infrastructure **100% Cloud sous Proxmox**.
Puisque vous n'avez pas de "Box Internet", c'est votre **serveur Proxmox** qui joue le rôle de routeur/gateway.

## 1. Principe Général

*   **Internet** arrive sur l'IP Publique de votre Proxmox (ex: `123.45.67.89`).
*   **Proxmox** doit rediriger (NAT) les ports 80 et 443 vers votre VM HAProxy (`192.168.50.200`).
*   **HAProxy** distribue ensuite au cluster Kubernetes.

## 2. Configuration DNS (BookMyName)

1.  Connectez-vous à **BookMyName**.
2.  Pointez `*.boudboud.fr` vers **l'IP Publique de votre serveur Proxmox**.

| Type | Nom | Valeur |
| :--- | :--- | :--- |
| **A** | `*` | `[IP_PUBLIQUE_PROXMOX]` |

## 3. Configuration Réseau sur le Hôte Proxmox

Vous devez exécuter ces commandes **sur le serveur Proxmox** (en SSH root) pour activer la redirection.

### A. Activer l'IP Forwarding
Assurez-vous que le routage est activé dans le noyau.

```bash
# Vérifier si activé (doit retourner 1)
cat /proc/sys/net/ipv4/ip_forward

# Si 0, activer temporairement :
echo 1 > /proc/sys/net/ipv4/ip_forward

# Pour rendre permanent, éditez /etc/sysctl.conf :
# net.ipv4.ip_forward=1
```

### B. Règles IPTables (NAT)
C'est ici que l'on remplace la "Box". On dit à Proxmox : "Tout ce qui arrive sur 80/443, envoie-le à 192.168.50.200".

Remplacez `vmbr0` par votre interface publique (celle qui a l'IP publique, souvent `vmbr0`, `eno1` ou `eth0`).

```bash
# INTERFACE PUBLIQUE (A vérifier avec 'ip a', souvent vmbr0)
PUB_IF="vmbr0"

# Ouvre les ports au niveau du pare-feu local (si INPUT DROP par défaut)
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Règle de PREROUTING (Redirection entrante)
iptables -t nat -A PREROUTING -i $PUB_IF -p tcp --dport 80 -j DNAT --to 192.168.50.200:80
iptables -t nat -A PREROUTING -i $PUB_IF -p tcp --dport 443 -j DNAT --to 192.168.50.200:443

# Règle de POSTROUTING (Masquerading pour que le retour se fasse bien)
iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o $PUB_IF -j MASQUERADE
```

> **Important :** Ces règles sont perdues au redémarrage. Pour les rendre persistantes, ajoutez-les dans `/etc/network/interfaces` sous votre interface principale (`post-up`) ou utilisez `iptables-save > /etc/iptables.rules`.

### Exemple de configuration `/etc/network/interfaces` persistante

```auto
auto vmbr0
iface vmbr0 inet static
    address  123.45.67.89/24
    gateway  123.45.67.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    # ... règles existantes ...
    
    # Redirection HAProxy
    post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 80 -j DNAT --to 192.168.50.200:80
    post-up iptables -t nat -A PREROUTING -i vmbr0 -p tcp --dport 443 -j DNAT --to 192.168.50.200:443
    # Masquerade (souvent déjà là pour que les VMs aient internet)
    post-up iptables -t nat -A POSTROUTING -s '192.168.50.0/24' -o vmbr0 -j MASQUERADE
```

## 4. Vérification HAProxy & Kubernetes

Comme vu précédemment, rien à changer ici.
*   **HAProxy** écoute déjà sur 80/443.
*   **Kubernetes** (Gateway API) attend le trafic sur NodePorts 30080/30443, et HAProxy fait le lien.
*   Il ne vous reste qu'à créer vos **HTTPRoute** pour vos services.

## Résumé des actions
1.  **DNS** : `*.boudboud.fr` -> IP Publique Proxmox.
2.  **SSH Proxmox** : Appliquer les règles `iptables` (DNAT 80 & 443 -> 192.168.50.200).
3.  **K8s** : Déployer vos `HTTPRoute`.
