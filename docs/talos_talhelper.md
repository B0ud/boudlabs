# Gestion Avancée de Talos avec Talhelper et SOPS

Cette méthode "GitOps-ready" permet de générer les configurations de manière déclarative et sécurisée. Contrairement à `talosctl gen config` qui crée des fichiers statiques non modifiables facilement, `talhelper` permet de définir tout le cluster dans un seul fichier YAML et de chiffrer les secrets.

## 1. Outils Nécessaires

Installez les outils suivants sur votre poste de travail (via `brew`, `chocolatey` ou téléchargement direct) :

*   **[Talosctl](https://github.com/siderolabs/talos/releases)** : CLI officiel.
*   **[Talhelper](https://github.com/budimanjojo/talhelper)** : Générateur de config déclaratif.
*   **[SOPS](https://github.com/getsops/sops)** : Outil de chiffrement de Mozilla.
*   **[Age](https://github.com/FiloSottile/age)** : Outil de chiffrement de clés simple et moderne.

## 2. Initialisation des Secrets (Age + SOPS)

Nous utilisons **Age** pour générer une clé de chiffrement, et **SOPS** pour chiffrer le fichier de secrets avec cette clé.

### 2.1 Générer la clé Age

```bash
# Génère une clé et la sauvegarde dans un fichier texte
age-keygen -o age.key.txt
```

*Note : Ajoutez `age.key.txt` à votre `.gitignore`. Ne jamais commiter ce fichier !*

### 2.2 Configurer SOPS

Créez un fichier `.sops.yaml` à la racine de votre dossier de configuration :

```yaml
creation_rules:
  - path_regex: .*\.sops\.yaml$
    key_groups:
      - age:
          - "age1..." # Copiez ici la CLÉ PUBLIQUE (visible dans age.key.txt)
```

## 3. Workflow de Configuration

### 3.1 Générer les secrets Talos

Talhelper peut générer un fichier de secrets chiffré pour vous.

```bash
# Définit la variable d'environnement pour que SOPS trouve la clé
# IMPORTANT SUR WINDOWS (Bash) : Utilisez le chemin ABSOLU avec des slashs '/'
export SOPS_AGE_KEY_FILE="d:/Mehdi/Documents/BoudLabs/talos/age.key.txt"

# Génère et chiffre les secrets
talhelper gensecret > talsecret.sops.yaml
```

Pour voir ou éditer les secrets déchiffrés :
```bash
sops talsecret.sops.yaml
```

### 3.2 Définir le Cluster (`talconfig.yaml`)

Créez votre `talconfig.yaml`. C'est la source unique de vérité. Il référence les nœuds, le réseau, et les patchs.

```yaml
clusterName: proxmox-cluster
talosVersion: v1.12.0
kubernetesVersion: v1.35.0
endpoint: https://192.168.50.100:6443 # VIP du Control Plane

# ... Nodes definition ...
```

### 3.3 Générer les fichiers finaux

Une fois `talconfig.yaml` et `talsecret.sops.yaml` prêts, générez les fichiers pour chaque nœud :

```bash
talhelper genconfig
```

Cela va créer un dossier `clusterconfig/` (ou les fichiers à la racine selon config) contenant :
*   `controlplane-master-01.yaml`
*   `worker-01.yaml`
*   `talosconfig` (Pour votre accès admin)

## 4. Dépannage (Troubleshooting)

### Erreur : `SOPS decryption failed: Error getting data key`

**Symptôme** : SOPS n'arrive pas à trouver la clé privée `age` pour déchiffrer.

**Cause fréquente sur Windows** : Si vous utilisez Git Bash ou WSL, le chemin relatif (`$(pwd)/age.key.txt`) ou le format Windows (`d:\...`) peut mal passer.

**Solution** :
Forcer le chemin absolu avec des forward slashes `/`.

```bash
export SOPS_AGE_KEY_FILE="d:/Mehdi/Documents/BoudLabs/talos/age.key.txt"
```
