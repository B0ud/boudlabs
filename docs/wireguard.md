# Sécurisation avec WireGuard

Pour limiter la surface d'attaque, l'interface de gestion Proxmox (port 8006) et SSH (port 22) ne seront accessibles qu'au travers du VPN WireGuard.

## Plan d'adressage

*   **Serveur Proxmox (VPN IP)** : `10.0.100.1`
*   **PC Client (VPN IP)** : `10.0.100.2`
*   **Mobile Client (VPN IP)** : `10.0.100.3`
*   **Réseau cible (VMs)** : `192.168.50.0/24`

## 1. Installation sur le Serveur (Proxmox)

Connectez-vous en SSH à votre serveur et installez les outils nécessaires :

```bash
apt update && apt install wireguard qrencode -y
```

Activez le forwarding IP (si ce n'est pas déjà fait) pour permettre le routage vers les VMs :

```bash
# Vérifier si activé
sysctl net.ipv4.ip_forward

# Activer de façon persistante
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

## 2. Génération des Clés

### Sur le Client (Windows)
Le client Windows gère ses propres clés pour plus de sécurité.

1.  Ouvrez l'application **WireGuard** sur Windows.
2.  Cliquez sur la flèche à côté de "Ajouter un tunnel" > **Ajouter un tunnel vide**.
3.  Copiez la **Clé Publique** affichée (nous en aurons besoin sur le serveur).
4.  Laissez la fenêtre ouverte.

### Sur le Serveur
Générez uniquement les clés du serveur, puis des clés pour le mobile :

```bash
cd /etc/wireguard
umask 077
# Clés Serveur
wg genkey | tee server_private.key | wg pubkey > server_public.key
# Clés Mobile
wg genkey | tee mobile_private.key | wg pubkey > mobile_public.key
```

Affichez les clés pour la configuration :

```bash
echo "=== Clé Publique SERVEUR (Pour Windows) ===" && cat server_public.key
echo "=== Clé Privée SERVEUR (Pour wg0.conf) ===" && cat server_private.key
echo "=== Clé Publique MOBILE (Pour wg0.conf) ===" && cat mobile_public.key
```

## 3. Configuration

### Côté Serveur (`/etc/wireguard/wg0.conf`)

Créez ou éditez le fichier :

```bash
nano /etc/wireguard/wg0.conf
```

Collez la configuration suivante (remplacez les placeholders) :

```ini
[Interface]
# L'IP du Serveur VPN
Address = 10.0.100.1/24
ListenPort = 51820
PrivateKey = <CLE_PRIVEE_SERVEUR>

# Sauvegarde auto désactivée
SaveConfig = false

# Démarrage : On active le forwarding et le NAT pour sortir sur Internet (vmbr0)
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o vmbr0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o vmbr0 -j MASQUERADE

[Peer]
# PC Windows
PublicKey = <CLE_PUBLIQUE_WINDOWS>
AllowedIPs = 10.0.100.2/32

[Peer]
# Mobile
PublicKey = <CLE_PUBLIQUE_MOBILE>
AllowedIPs = 10.0.100.3/32
```

Activez/Redémarrez WireGuard :

```bash
systemctl enable --now wg-quick@wg0
# OU si déjà lancé
systemctl restart wg-quick@wg0
```

### Côté Client (Windows)

Retournez sur la fenêtre "Tunnel vide" de votre PC et complétez la configuration :

```ini
[Interface]
PrivateKey = <CLE_PRIVEE_DEJA_REMPLIE>
Address = 10.0.100.2/32
DNS = 1.1.1.1

[Peer]
# Infos du Serveur OVH
PublicKey = <CLE_PUBLIQUE_SERVEUR>
Endpoint = <IP_PUBLIQUE_DE_TON_SERVEUR_OVH>:51820
# Routage : VPN + Réseau VMs (192.168.50.x)
AllowedIPs = 10.0.100.0/24, 192.168.50.0/24
PersistentKeepalive = 25
```

### Côté Client (Mobile : Android / iOS)

Pour le mobile, nous allons générer un QR Code sur le serveur.

1.  Créez un fichier temporaire : `nano mobile-config.conf`
2.  Collez le contenu suivant en remplaçant les valeurs :

    ```ini
    [Interface]
    Address = 10.0.100.3/32
    PrivateKey = <CLE_PRIVEE_MOBILE>
    DNS = 1.1.1.1

    [Peer]
    PublicKey = <CLE_PUBLIQUE_SERVEUR>
    Endpoint = <IP_PUBLIQUE_SERVEUR>:51820
    AllowedIPs = 10.0.100.0/24, 192.168.50.0/24
    PersistentKeepalive = 25
    ```

3.  Générez le QR Code dans le terminal :

    ```bash
    qrencode -t ansiutf8 < mobile-config.conf
    ```

4.  Scannez le QR Code avec l'app WireGuard sur votre téléphone.
5.  **Important** : Supprimez le fichier temporaire pour des raisons de sécurité.

    ```bash
    rm mobile-config.conf
    ```

## 4. Mise à jour du Firewall (CRITIQUE)

Si vous utilisez un script de pare-feu local (ex: `/root/firewall.sh`), vous devez mettre à jour la définition du réseau VPN pour correspondre au nouveau plan d'adressage.

1.  Éditez le script : `nano /root/firewall.sh`
2.  Modifiez la variable `WG_NET` :
    ```bash
    WG_NET="10.0.100.0/24"
    ```
3.  Appliquez les changements :
    ```bash
    /root/firewall.sh
    netfilter-persistent save
    ```

## 5. Tests

1.  **Connexion** : Activez le tunnel sur Windows et Mobile (testez séparément ou ensemble).
2.  **Ping** : `ping 10.0.100.1` doit répondre.
3.  **Proxmox** : Accédez à `https://10.0.100.1:8006`.
4.  **VMs** : Si une VM est sur `192.168.50.x`, elle doit être accessible par Ping/SSH.
