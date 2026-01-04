# Provisioning Infrastructure avec OpenTofu (Terraform)

Nous utilisons l'Infrastructure as Code (IaC) pour créer et gérer les VMs Proxmox de manière reproductible.

## 1. Outils Nécessaires

*   **[OpenTofu](https://opentofu.org/)** : Fork open-source de Terraform.

    **Installation** :
    *   Windows (Winget) :
        ```powershell
        winget install --exact --id=OpenTofu.Tofu
        ```
    *   Linux (Fedora/RHEL) :
        ```bash
        dnf install opentofu
        ```

## 2. Structure du Projet

Le code Terraform se trouve dans le dossier `talos-setup-ovh/` (ou racine selon setup).

*   `main.tf` : Définition de l'infrastructure (Provider Proxmox, Ressources VMs).
*   `terraform.tfvars` : **Ficher Secret** contenant vos identifiants. **NE JAMAIS LE COMMITTER**.
*   `.gitignore` : Configuré pour ignorer `.tfvars` et `.tfstate`.

## 3. Configuration Initiale

### 3.1 Créer le fichier de variables secrètes

Créez un fichier `terraform.tfvars` (s'il n'existe pas) :

```hcl
proxmox_password = "VOTRE_MOT_DE_PASSE_SECURISE"
proxmox_user     = "root@pam"
```

### 3.2 Initialiser le projet

Dans le dossier contenant `main.tf` :

```bash
tofu init
```
Cela va télécharger le plugin `telmate/proxmox`.

## 4. Workflow Quotidien

### Prévisualiser les changements

Avant d'appliquer quoi que ce soit, vérifiez ce que Tofu va faire :

```bash
tofu plan
```
*   Vérifiez que les IPs correspondent bien à ce que vous attendez.
*   Assurez-vous qu'il ne détruit pas de VMs par erreur (Destroy).

### Appliquer les changements

Si le plan est bon :

```bash
tofu apply
```
Répondez `yes` pour confirmer.

## 5. Détails Techniques Importants

### Le Template ("Clone")
Le code `main.tf` fait référence à un `template_name` (ex: `talos-template-nocloud`).
Ce template **doit exister** sur Proxmox avant de lancer Tofu.

**Pour Talos**, l'idéal est d'avoir une image Cloud-Init. Si vous clonez une VM qui a juste booté sur l'ISO, la configuration `ipconfig0` (IP statique) définie dans Terraform ne sera **PAS** prise en compte automatiquement, car l'ISO Talos standard n'utilise pas Cloud-Init par défaut.

> [!TIP]
> **Recommandation** : Utilisez le script de génération de Template "Factory" pour avoir une image compatible Cloud-Init.
> **[Voir le guide : Création du Template Talos](talos_template.md)**

### Sécurité (State)
Le fichier `terraform.tfstate` qui est créé après un `apply` contient l'état de votre infra, y compris certaines données sensibles. Il est exclu du Git (`.gitignore`). Gardez-le précieusement sur votre machine (ou configurez un backend distant sécurisé type S3/MinIO plus tard).

## 6. Spécificités de Configuration (Provider Telmate)

Voici les configurations spécifiques requises pour le provider `telmate/proxmox` (v3.0.x) afin d'éviter les erreurs courantes.

### Cloud-Init
L'argument `cloudinit_cdrom_storage` est obsolète. Utilisez un bloc `disk` dédié de type `cloudinit` :
```hcl
disk {
  slot    = "ide2"
  type    = "cloudinit"
  storage = "local"
}
```

### Disques
Le stockage principal doit spécifier un slot (ex: `scsi0`) et le type `disk` :
```hcl
disk {
  slot    = "scsi0"
  type    = "disk"
  storage = "local"
  size    = "100G"
}
```

### CPU
Les cœurs doivent être définis dans un bloc `cpu`, l'argument `cores` racine est déprécié :
```hcl
cpu {
  cores = 4
}
```

### Boot
Pour démarrer la VM à la création, utilisez `start_at_node_boot = true` (remplace `onboot`).

## 7. Accès au Cluster (Post-Installation)

Une fois le `tofu apply` terminé avec succès, le cluster est prêt. Cependant, les fichiers de connexion sont stockés dans les "outputs" de Terraform et sont marqués comme sensibles (masqués).

### 7.1 Récupérer les fichiers de configuration

Exécutez ces commandes dans votre terminal (dossier `talos-setup-ovh`) pour extraire les fichiers :

```bash
# Extraire le kubeconfig (pour kubectl)
tofu output -raw kubeconfig > kubeconfig

# Extraire le talosconfig (pour talosctl)
tofu output -raw talosconfig > talosconfig
```

### 7.2 Configurer l'environnement

Pour utiliser ces fichiers sans avoir à les spécifier à chaque commande (`--kubeconfig ...`), exportez les variables d'environnement :

```bash
# Linux / macOS / Git Bash
export KUBECONFIG=./kubeconfig
export TALOSCONFIG=./talosconfig

# PowerShell
$env:KUBECONFIG="$PWD\kubeconfig"
$env:TALOSCONFIG="$PWD\talosconfig"
```

### 7.3 Vérifier l'accès

1.  **Kubernetes** (Vérifier que les nœuds sont Ready) :
    ```bash
    kubectl get nodes
    ```

2.  **Talos** (Accéder au Dashboard d'un nœud, ex: master-01) :
    ```bash
    # Remplacez l'IP par celle de votre master-01
    talosctl -n 192.168.50.110 dashboard
    ```

## 8. Debugging & Logs

Si `tofu apply` échoue ou semble bloqué, vous pouvez activer les logs détaillés pour comprendre ce qui se passe (appels API, erreurs masquées, etc.).

### Activer les logs

Définissez la variable d'environnement `TF_LOG`. Les niveaux possibles sont : `INFO`, `WARN`, `ERROR`, `DEBUG`, `TRACE` (le plus verbeux).

```powershell
# PowerShell
$env:TF_LOG="DEBUG"
$env:TF_LOG_PATH="debug.log" # Optionnel : pour écire dans un fichier
```

```bash
# Bash
export TF_LOG=DEBUG
export TF_LOG_PATH=debug.log
```

Une fois activé, relancez votre commande `tofu plan` ou `tofu apply`.

> **Attention au volume** : Le niveau `TRACE` génère énormément de texte. Pensez à désactiver les logs une fois le debug terminé (`$env:TF_LOG=""` ou `unset TF_LOG`).

## 9. Installation CNI (Cilium)

Pour gérer le réseau du cluster Kubernetes, nous utilisons **Cilium** installé via le provider Helm de Terraform.

### 9.1 Configuration du Provider Helm (v3)

**Important** : La version 3.x du provider Helm utilise une syntaxe spécifique. L'argument `kubernetes` doit être défini comme un attribut (avec un `=`) et non comme un bloc.

```hcl
provider "helm" {
  kubernetes = {
    host                   = ...
    client_certificate     = ...
    client_key             = ...
    cluster_ca_certificate = ...
  }
}
```

### 9.2 Ressource `helm_release`

Nous déployons Cilium avec des options spécifiques pour Talos (IPAM Kubernetes, KubeProxy Replacement, Gateway API).
Pour le provider v3, il est recommandé d'utiliser la syntaxe `set = [...]` (liste d'objets) plutôt que des blocs `set {}` répétés.

**Extrait de configuration (`main.tf`) :**

```hcl
resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.18.5" # Ou version plus récente
  namespace  = "kube-system"

  set = [
    {
      name  = "ipam.mode"
      value = "kubernetes"
    },
    {
      name  = "kubeProxyReplacement"
      value = "true"
    },
    {
      name  = "securityContext.capabilities.ciliumAgent"
      value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
    },
    {
      name  = "securityContext.capabilities.cleanCiliumState"
      value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
    },
    {
      name  = "cgroup.autoMount.enabled"
      value = "false"
    },
    {
      name  = "cgroup.hostRoot"
      value = "/sys/fs/cgroup"
    },
    {
      name  = "k8sServiceHost"
      value = "localhost"
    },
    {
      name  = "k8sServicePort"
      value = "7445"
    },
    {
      name  = "gatewayAPI.enabled"
      value = "true"
    },
    {
      name  = "gatewayAPI.enableAlpn"
      value = "true"
    },
    {
      name  = "gatewayAPI.enableAppProtocol"
      value = "true"
    }
  ]
}
```
