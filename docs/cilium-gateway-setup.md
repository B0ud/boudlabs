# Architecture Réseau & Gateway API

Ce document détaille l'implémentation de la Gateway API Cilium sur notre cluster Talos on-premise. L'objectif est d'exposer nos services Kubernetes via des IPs fixes (les nœuds du cluster) en utilisant des **NodePorts statiques**, tout en laisser Cilium gérer le routage L7.

## Architecture

L'implémentation standard de Cilium Gateway API génère des services avec des NodePorts *aléatoires*. Pour contourner cela et permettre à notre load balancer externe (HAProxy) de cibler des ports fixes, nous **patchons** directement les services générés par Cilium.

### Diagramme de Flux

```mermaid
graph TD
    subgraph Internet
        User([Utilisateur])
    end

    subgraph "Infrastructure Externe (VM)"
        HAProxy[HAProxy Load Balancer]
    end

    subgraph "Cluster Kubernetes (Talos)"
        subgraph "Services (Namespace: networking)"
            GatewaySvc[Service Gateway Cilium<br/>(NodePort Patché)<br/>Ports: 30080, 30443...]
        end
        
        GatewayPod[Pod Cilium Gateway<br/>(Envoy Proxy)]
        Routes[HTTPRoutes]
        
        subgraph "Application"
            AppPod[Pod Application<br/>ex: PodInfo]
        end
    end

    User -->|HTTPS| HAProxy
    HAProxy -->|Port 31443| GatewaySvc
    HAProxy -->|Port 30443| GatewaySvc
    
    GatewaySvc -->|Selecteur| GatewayPod
    GatewayPod -->|Routing L7| AppPod

    style GatewaySvc fill:#9f9,stroke:#333,stroke-width:2px
```

## Composants Clés

### 1. GatewayClass Personnalisée (`user-gateway-class.yaml`)
Nous définissons une `GatewayClass` spécifique (`cilium-nodeport`) pour forcer le mode **NodePort**.

```yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumGatewayClassConfig
metadata:
  name: cilium-nodeport
spec:
  service:
    type: NodePort
```

### 2. Patch des Services
Cilium génère automatiquement des services nommés `cilium-gateway-<nom-gateway>`.
Nous appliquons un patch (via Kustomize ou manuellement) pour écraser les ports aléatoires par nos ports statiques définis.

**Ports Statiques :**
- **Gateway Publique** (`cilium-gateway-gateway-public`) :
  - HTTP: 30080
  - HTTPS: 30443
- **Gateway Privée** (`cilium-gateway-gateway-privee`) :
  - HTTP: 31080
  - HTTPS: 31443

### 3. HAProxy (Externe)
HAProxy redirige le trafic entrant vers les IPs des nœuds Workers sur ces ports statiques précis.

## Déploiement

Tout est géré via GitOps (FluxCD). Les fichiers se trouvent dans `gitops/3_gateway_cillium`.

### Ajout d'une nouvelle Gateway
1. Définissez la `Gateway` en utilisant la classe `cilium-nodeport`.
2. Identifiez le nom du service généré par Cilium (`cilium-gateway-<votre-nom>`).
3. Ajoutez un patch dans `kustomization.yaml` (section `patches`) pour fixer le `nodePort` du service généré.
4. Mettez à jour HAProxy si nécessaire.

## Vérification

Pour valider que la configuration fonctionne correctement (depuis l'intérieur du réseau ou via HAProxy), vous pouvez utiliser `curl`.

### Test HTTPS (avec résolution DNS forcée)
Cette commande permet de tester l'accès via le nom de domaine `demo.private.local` en forçant la résolution vers l'IP de votre Load Balancer (ou d'un nœud worker si test direct).

```bash
curl -v -k https://demo.private.local --resolve demo.private.local:443:192.168.50.200
```
*Note: Remplacez `192.168.50.200` par l'IP de votre HAProxy.*

### Test HTTP
De la même manière pour le port 80 :
```bash
curl -v -H "Host: demo.private.local" http://192.168.50.200
```
