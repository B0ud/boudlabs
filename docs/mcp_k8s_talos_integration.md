# Intégration Kubernetes & Talos avec MCP (Model Context Protocol)

Ce document décrit la procédure pour intégrer Kubernetes et Talos Linux avec votre environnement MCP. Cela permet à l'IA d'interagir directement avec vos clusters pour le débogage, la surveillance et la gestion.

## 1. Intégration Kubernetes

Le serveur MCP Kubernetes permet à l'IA d'utiliser l'API K8s (équivalent à `kubectl`).

### Prérequis
*   Avoir `kubectl` installé et configuré.
*   Avoir un fichier `kubeconfig` valide (dans `~/.kube/config` ou via la variable `KUBECONFIG`).
*   Node.js installé (pour `npx`).

### Installation & Configuration (Client MCP)

Ajoutez cette entrée à votre configuration MCP (`config.json`). Nous utilisons ici le serveur officiel de la communauté via `npx` (exécuté à la volée).

```json
{
  "mcpServers": {
    "kubernetes": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-kubernetes"],
      "env": {
        "KUBECONFIG": "d:/Mehdi/Documents/BoudLabs/infrastructure/kubeconfig" 
      }
    }
  }
}
```
*Note : Adaptez le chemin du KUBECONFIG vers votre fichier réel (ici, celui de votre projet BoudLabs).*

### Fonctionnalités
L'IA pourra :
*   Lister les Pods, Services, Deployments (`kubectl get ...`).
*   Lire les logs (`kubectl logs ...`).
*   Décrire les ressources pour analyser les erreurs (`kubectl describe ...`).

---

## 2. Intégration Talos Linux

Le serveur MCP Talos permet à l'IA d'interagir avec l'OS des nœuds (équivalent à `talosctl`).

### Prérequis
*   Avoir `talosctl` installé.
*   Avoir un fichier `talosconfig` valide.
*   Python 3.10+ et `uv` installés.

### Installation (Serveur Local)

Il est recommandé d'installer ce serveur localement via Python.
*Exemple basé sur une implémentation communautaire (ex: `mcp-server-talos`)*.

```bash
# 1. Cloner ou créer le projet (si disponible sur PyPI/Github)
# Exemple générique :
git clone https://github.com/project-mcp/mcp-server-talos # (URL à adapter selon le projet choisi)
cd mcp-server-talos

# 2. Installer
uv venv
uv pip install .
```

### Configuration (Client MCP)

```json
{
  "mcpServers": {
    "talos": {
      "command": "python",
      "args": ["-m", "mcp_server_talos"],
      "env": {
        "TALOSCONFIG": "d:/Mehdi/Documents/BoudLabs/infrastructure/talosconfig",
        "TALOS_CONTEXT": "proxmox-cluster"
      }
    }
  }
}
```

### Fonctionnalités
L'IA pourra :
*   Vérifier l'état des membres (`talosctl get members`).
*   Voir les processus et services système.
*   Gérer les disques et le réseau des nœuds.

## 3. Résumé de la Configuration Complète

Voici à quoi pourrait ressembler votre section `mcpServers` complète (Proxmox + K8s + Talos) :

```json
{
  "mcpServers": {
    "proxmox": {
      "command": "python",
      "args": ["-m", "proxmox_mcp"],
      "env": { ... }
    },
    "kubernetes": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-kubernetes"],
      "env": {
        "KUBECONFIG": "C:/Users/Mehdi/.kube/config"
      }
    },
    "talos": {
      "command": "python",
      "args": ["-m", "mcp_server_talos"],
      "env": {
        "TALOSCONFIG": "C:/Users/Mehdi/.talos/config"
      }
    }
  }
}
```
