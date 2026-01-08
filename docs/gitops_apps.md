# Applications GitOps (Apps of Apps)

Ce document décrit la structure utilisée pour gérer les applications Kubernetes via FluxCD et documente les composants système installés.

## Structure "Apps of Apps"

Pour organiser proprement le déploiement des applications, nous utilisons le pattern "Apps of Apps".
Le dépôt Git est structuré de la manière suivante :

*   `gitops/0_fluxcd/` : Configuration système de Flux (bootstrappé via CLI).
*   `gitops/1_apps-of-apps/` : Point d'entrée pour les applications.
*   `gitops/2_.../` : Dossiers des applications spécifiques (ex: Cert-Manager).

Flux surveille d'abord `1_apps-of-apps`. Ce dossier contient des objets `Kustomization` (Flux) qui pointent vers les dossiers spécifiques des applications (comme `2_cert-manager`). Cela permet de séquencer les déploiements et de garder une racine propre.

## Composants Installés

### 1. Gateway API (CRDs)

Les Custom Resource Definitions (CRDs) de la Gateway API sont installées directement depuis le dépôt officiel Kubernetes. Elles sont nécessaires pour utiliser les nouvelles ressources de routage (`Gateway`, `HTTPRoute`) qui remplacent progressivement Ingress.

*   **Version** : v1.4.1 (Standard Install)
*   **Source** : `https://github.com/kubernetes-sigs/gateway-api/.../standard-install.yaml`
*   **Déclaration** : `gitops/1_apps-of-apps/kustomization.yaml`

### 2. Cert-Manager

Cert-Manager est utilisé pour gérer automatiquement les certificats TLS (notamment via Let's Encrypt) dans le cluster.

*   **Installation** : Via Helm Controller (Flux).
*   **Emplacement** : `gitops/2_cert-manager/`
*   **Namespace** : `cert-manager`

#### Configuration
L'installation repose sur 3 fichiers principaux :
1.  `helm-repository.yaml` : Déclare la source des chartes (OCI Registry de Jetstack : `oci://quay.io/jetstack/charts`).
2.  `helm-release.yaml` : Déploie la charte `cert-manager`.
    *   **Paramètre critique** : `installCRDs: true` (pour installer les CRDs Cert-Manager).
3.  `kustomization.yaml` : Regroupe les ressources pour Flux.

#### Vérification
Pour vérifier que Cert-Manager est bien installé, listez les pods dans le namespace dédié :

```bash
kubectl get pods -n cert-manager
```

Vous devriez voir 3 composants :
*   `cert-manager` (contrôleur principal)
*   `cert-manager-cainjector`
*   `cert-manager-webhook`
