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
> **Recommandation** : Utilisez une image générée avec `talosctl gen iso` ou `talosctl gen image` qui inclut déjà les configurations, ou assurez-vous que votre Template est configuré pour lire les metadata Cloud-Init (plateforme `nocloud`).

### Sécurité (State)
Le fichier `terraform.tfstate` qui est créé après un `apply` contient l'état de votre infra, y compris certaines données sensibles. Il est exclu du Git (`.gitignore`). Gardez-le précieusement sur votre machine (ou configurez un backend distant sécurisé type S3/MinIO plus tard).
