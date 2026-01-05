# Mise à jour du Cluster (Talos & Kubernetes)

Ce guide explique comment mettre à jour l'OS Talos Linux ainsi que Kubernetes, et comment résoudre les problèmes courants.

---

## 1. Mise à jour de Talos Linux (OS)

La mise à jour de Talos s'effectue nœud par nœud de manière sécurisée (l'API gère le drain et le reboot).

### Vérifier la version actuelle et les nœuds
```bash
talosctl version
talosctl get members
```

### Lancer la mise à jour
Utilisez l'image de l'installateur correspondant à la version cible (ex: `v1.12.0`).

```bash
# Exemple pour mettre à jour un nœud spécifique (ex: 192.168.50.110)
talosctl upgrade \
  --nodes 192.168.50.110 \
  --image ghcr.io/siderolabs/installer:v1.12.0
```

*   **Option `--preserve`** : Conserve les données de la partition système (généralement non requis sauf cas spécifique).
*   **Option `--force`** : Force la mise à jour même si des vérifications de santé échouent (ex: si le cluster est dégradé). À utiliser avec précaution.

---

## 2. Mise à jour de Kubernetes

Une fois que vos nœuds Talos sont à jour (ou supportent la version cible de K8s), vous pouvez mettre à jour Kubernetes.

### Lancer la mise à jour
```bash
# Pour mettre à jour vers une version spécifique (ex: 1.34.3)
talosctl upgrade-k8s --to 1.34.3 --nodes 192.168.50.110
```
*Note : Pointez vers l'IP d'un nœud de contrôle (Master).*

---

## 3. Résolution de Problèmes (Troubleshooting)

### Erreur : `unknown keys found during decoding: machine: install: grubUseUKICmdline`

Cette erreur survient généralement lors d'une tentative de mise à jour ou d'application de configuration lorsque le client `talosctl` ou la configuration générée est plus récente que la version de Talos installée sur les nœuds.

**Cause :**
*   **Cas 1 (Client Obsolète)** : Votre client `talosctl` local est en v1.11 alors que vous essayez d'interagir avec des configs v1.12.
*   **Cas 2 (Nœud Obsolète)** : Vous essayez d'appliquer une config v1.12 (avec `grubUseUKICmdline`) sur un nœud qui tourne encore en v1.11.

**Solution :**

1.  **Mettre à jour le client `talosctl`** :
    ```bash
    # Windows
    winget install siderolabs.talosctl
    # Linux/Mac
    curl -sL https://talos.dev/install | sh
    ```

2.  **Aligner les versions** :
    Si vous êtes dans le "Cas 2", vous devez d'abord mettre à jour l'OS Talos vers la version requise par votre config (v1.12+) en utilisant l'option `--force` si la validation de config bloque la mise à jour normale :
    ```bash
    talosctl upgrade --nodes <IP> --image ghcr.io/siderolabs/installer:v1.12.0 --force
    ```
