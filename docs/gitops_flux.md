# GitOps avec FluxCD

Ce document détaille l'implémentation de la méthodologie GitOps sur le cluster BoudLabs en utilisant FluxCD, installé et géré via Terraform.

## Vue d'ensemble

Le cluster utilise une approche hybride :
1.  **Infrastructure (Terraform)** : Provisionning des VMs Proxmox, installation de Talos Linux, et configuration réseau de base (Cilium).
2.  **Applications (FluxCD)** : Gestion du cycle de vie des applications Kubernetes via synchronisation Git.

## Structure des Dossiers

*   **`infrastructure/`** : Code Terraform gérant :
    *   Les VMs et le cluster Talos (`main.tf`, `variables.tf`, etc.).
    *   Le bootstrap de FluxCD (`flux.tf`).
    *   Les providers (`providers.tf`).
*   **`gitops/`** : Racine du référentiel GitOps. Ce dossier contiendra tous les manifestes Kubernetes (YAML, Kustomizations, HelmReleases) que Flux doit appliquer sur le cluster.

## Installation via Terraform

L'installation de Flux est automatisée par Terraform sans nécessiter l'installation du binaire `flux` en local.

### 1. Prérequis (Variable Terraform)

Terraform a besoin d'un accès à GitHub pour créer la clé de déploiement et commiter les composants Flux initiaux. Les variables suivantes doivent être définies (via `terraform.tfvars` ou variables d'environnement) :

```hcl
github_owner    = "VotrePseudo"
github_token    = "ghp_xxxxxxxxxxxx" # Token avec scope 'repo' ou 'contents:write'
repository_name = "BoudLabs"
github_branch   = "main"
```

### 2. Provider Flux (`providers.tf`)

Le provider est configuré pour se connecter au cluster Kubernetes (via les certificats générés par Talos) et à GitHub.

```hcl
provider "flux" {
  kubernetes = {
    host = ... # Récupéré depuis l'output de Talos
    # ... certificats clients
  }
  git = {
    url = "https://github.com/${var.github_owner}/${var.repository_name}.git"
    http = {
      username = "git"
      password = var.github_token
    }
  }
}
```

### 3. Bootstrap (`flux.tf`)

La ressource `flux_bootstrap_git` assure l'installation. Elle est configurée pour dépendre de **Cilium** (`depends_on = [helm_release.cilium]`), car Flux a besoin d'un réseau fonctionnel (CNI) pour démarrer ses contrôleurs.

Elle pointe vers le dossier `gitops/` à la racine du projet :
```hcl
path = "${path.module}/../gitops"
```

## Workflow Utilisateur

Pour déployer une nouvelle application :

1.  Ne touchez plus à Terraform (sauf changement d'infra).
2.  Créez les manifestes Kubernetes dans le dossier `gitops/` (ex: `gitops/apps/mon-app.yaml`).
3.  Commitez et poussez sur la branche `main` :
    ```bash
    git add gitops/
    git commit -m "Add new app"
    git push origin main
    ```
4.  Flux détectera automatiquement les changements et mettra à jour le cluster.

## Gestion des Mises à jour

*   **Mise à jour de Flux** : Modifier la version du provider ou des composants dans Terraform, puis `tofu apply`.
*   **Mise à jour des Apps** : Modifier les fichiers YAML dans `gitops/` et git push.
