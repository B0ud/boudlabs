# Installation Manuelle de FluxCD

Ce guide détaille la procédure pour bootstraper FluxCD manuellement sur le cluster BoudLabs. Cette méthode est recommandée lorsque l'automatisation via Terraform rencontre des problèmes spécifiques à l'environnement (ex: Windows).

## Prérequis

1.  **Cluster Kubernetes accessible** :
    *   Le fichier `kubeconfig` doit être généré et accessible.
    *   La variable d'environnement `KUBECONFIG` doit être définie.
    *   Vérification : `kubectl get nodes` doit répondre "Ready".

2.  **CLI Flux installée** :
    *   Téléchargez le binaire (ex: `flux_X.Y.Z_windows_amd64.zip`) depuis les **[Releases GitHub officielles](https://github.com/fluxcd/flux2/releases)**.
    *   Extrayez l'exécutable `flux.exe`.
    *   Ajoutez le dossier contenant `flux.exe` à votre PATH système (ou placez-le dans un dossier déjà dans le PATH ex: `C:\Windows\System32`).

3.  **Token GitHub (PAT)** :
    *   Un Personal Access Token GitHub avec les droits `repo` complets.

## Procédure d'Installation

### 1. Préparer l'environnement

Assurez-vous d'être à la racine du dépôt `BoudLabs` :

```powershell
cd d:\Mehdi\Documents\BoudLabs
```

Exportez votre kubeconfig si ce n'est pas déjà fait :

```powershell
$env:KUBECONFIG="infrastructure/kubeconfig"
```

### 2. Lancer le Bootstrap

Exécutez la commande suivante pour installer Flux sur le cluster et le configurer pour se synchroniser avec le dépôt GitHub.

Remplacez `VOTRE_TOKEN` par votre PAT (ou entrez-le quand demandé si vous omettez l'export).

```powershell
flux bootstrap github `
  --token-auth `
  --owner=B0ud `
  --repository=boudlabs `
  --branch=main `
  --path=gitops/0_fluxcd `
  --personal
```

> **Note** : L'option `--personal` est utilisée si vous utilisez un compte utilisateur GitHub standard (pas une organisation). Si `B0ud` est une organisation, retirez cette option.

### 3. Résolution d'Erreur (Spécifique Windows / TMP)

Si vous rencontrez l'erreur :
`component manifest generation failed: Rel: can't make E:\TMP\... relative to D:\...`

Cela signifie que Flux a du mal à gérer les chemins temporaires sur un lecteur différent (`E:` vs `D:`).
**Solution de contournement** : Définissez le répertoire temporaire sur le même disque avant de lancer la commande.

```powershell
$env:TMP="D:\Temp"
mkdir D:\Temp -Force
# Relancer la commande flux bootstrap...
```

## Vérification

Une fois l'installation terminée :

1.  Vérifiez que les pods Flux tournent :
    ```bash
    kubectl get pods -n flux-system
    ```

2.  Vérifiez que la source Git est prête :
    ```bash
    flux get sources git
    ```

## Structure GitOps

Flux surveillera le dossier `gitops/0_fluxcd` de votre dépôt.
Tout fichier YAML ajouté dans ce dossier (ou ses sous-dossiers référencés via `kustomization.yaml`) sera automatiquement appliqué au cluster.
