# Installation et Configuration de Proxmox VE

## 1. Pré-requis

*   Un serveur dédié avec accès KVM/IPMI pour l'installation initiale.
*   Image ISO de Proxmox VE (dernière version stable).

## 2. Installation

1.  Booter sur l'ISO Proxmox VE.
2.  Suivre l'installateur graphique.
    *   **Target Harddisk**: Sélectionner le disque principal (RAID matériel ou ZFS software si plusieurs disques).
    *   **Country/Timezone**: Configurer selon la location.
    *   **Password/Email**: Définir un mot de passe root fort.
    *   **Network Configuration**:
        *   Management Interface: Choisir l'interface principale connecté au net.
        *   Hostname: `pve.boudlabs.local` (exemple).
        *   IP Address: L'IP publique du serveur.
        *   Gateway/DNS: Fournis par l'hébergeur.

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

### Configuration Réseau : Interface Publique (`vmbr0`)

C'est l'interface principale créée lors de l'installation. Elle porte l'IP publique.

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

### Configuration Réseau : Interface Privée avec NAT (`vmbr1`)

Nous allons créer un **réseau privé** ( 192.168.50.0/24) pour nos VMs et Conteneurs. Elles auront accès à internet grâce au NAT (Masquerading) via l'interface publique `vmbr0`.

#### 1. Éditer le fichier de configuration

```bash
nano /etc/network/interfaces
```

Ajoutez ce bloc à la fin du fichier :

```auto
# Réseau Privé pour les VMs (192.168.50.X) avec NAT
auto vmbr1
iface vmbr1 inet static
    address 192.168.50.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    # Activation du forwarding et du NAT
    post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up   iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s 192.168.50.0/24 -o vmbr0 -j MASQUERADE
```

*Note : Assurez-vous que `-o vmbr0` correspond bien au nom de votre interface publique définie plus haut.*

#### 2. Appliquer les changements

```bash
ifreload -a
```

#### 3. Vérification

```bash
ip a | grep vmbr1
# Doit afficher : inet 192.168.50.1/24 ...
```

## 4. Validation Complète : Création d'un Conteneur LXC (Nginx)

Pour valider que toute la chaîne fonctionne (VPN WireGuard -> Routage -> NAT -> VM/CT), nous allons créer un conteneur léger.

### Étape 1 : Télécharger le Template

1.  Dans Proxmox, aller dans **Datacenter > pve > local (pve)**.
2.  Cliquer sur **CT Templates**.
3.  Cliquer sur **Templates**, chercher `debian-12-standard` et **Télécharger**.

### Étape 2 : Créer le Conteneur

Cliquer sur **Créer CT** (en haut à droite) :

*   **Général** :
    *   Hostname : `nginx-test`
    *   Password : Définir un mot de passe root.
    *   Unprivileged : **Coché**.
*   **Modèle** : Choisir `debian-12-standard`.
*   **Disque** : Par défaut (8 Go).
*   **CPU/RAM** : Par défaut (1 Core / 512 Mo).
*   **Réseau** (CRITIQUE) :
    *   **Pont** : `vmbr1`
    *   **IPv4** : Statique
    *   **IPv4/CIDR** : `192.168.50.10/24`
    *   **Passerelle** : `192.168.50.1` (L'IP de Proxmox sur ce réseau).
*   **DNS** :
    *   Serveur DNS : `1.1.1.1` (Vital pour télécharger les paquets).
*   **Confirmer** : Cocher "Démarrer après création" et Terminer.

### Étape 3 : Installer Nginx

1.  Sélectionner le CT `100 (nginx-test)` à gauche.
2.  Aller dans **Console**.
3.  Login : `root` (et le mot de passe défini).
4.  Installer Nginx :
    ```bash
    apt update && apt install nginx -y
    ```
    *Si `apt update` fonctionne, cela confirme que le NAT est opérationnel (le conteneur a accès à internet).*

### Étape 4 : Le Verdict

Depuis votre PC (connecté au VPN WireGuard) :

1.  Ouvrez votre navigateur.
2.  Allez sur `http://192.168.50.10`.

**Succès** : Si vous voyez la page "Welcome to nginx!", cela confirme :
*   Le VPN fonctionne (accès au réseau serveur).
*   Le Routage fonctionne (accès du serveur vers le réseau privé 192.168.50.x).
*   Le Conteneur tourne et répond.
