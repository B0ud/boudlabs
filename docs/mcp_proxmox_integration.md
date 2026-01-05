# Intégration Proxmox avec MCP (Model Context Protocol)

Ce document décrit la procédure pour permettre à une IA (comme Antigravity ou Gemini via un IDE compatible) d'interagir directement avec votre infrastructure Proxmox via le protocole MCP.

## 1. Prérequis : Création du Token API Proxmox

L'IA a besoin d'un accès authentifié pour exécuter des commandes.

1.  Connectez-vous à l'interface web de Proxmox.
2.  Naviguez vers **Datacenter** > **Permissions** > **API Tokens**.
3.  Cliquez sur **Add**.
4.  Remplissez les champs :
    *   **User** : Sélectionnez l'utilisateur (ex: `root@pam`).
    *   **Token ID** : Donnez un nom (ex: `antigravity`).
    *   **Privilege Separation** :
        *   *Option 1 (Rapide)* : Décochez pour hériter des droits root (Attention sécurité).
        *   *Option 2 (Recommandé)* : Cochez, puis assignez des permissions spécifiques au Token ensuite.
5.  **COPIEZ LE SECRET MAINTENANT**. Il ne sera plus jamais affiché.
    *   Vous aurez besoin du `Token ID` (ex: `root@pam!antigravity`) et du `Secret` (UUID).

## 2. Installation du Serveur MCP (Machine Locale)

Le serveur MCP agit comme une passerelle. Il tourne localement sur votre machine de développement.

### Exemple avec ProxmoxMCP (Python)
*Lien du projet : https://github.com/canvrno/ProxmoxMCP (ou équivalent)*

```bash
# 1. Cloner le repository
git clone https://github.com/canvrno/ProxmoxMCP
cd ProxmoxMCP

# 2. Créer un environnement virtuel
uv venv  # ou python -m venv .venv
source .venv/bin/activate # (Sur Windows: .venv\Scripts\activate)

# 3. Installer le package
uv pip install .
```

## 3. Configuration de l'IDE (Client MCP)

Vous devez déclarer ce nouveau serveur dans la configuration MCP de votre IDE (fichier `config.json` d'Antigravity/Claude).

Ajoutez cette entrée dans la section `mcpServers` :

```json
{
  "mcpServers": {
    "proxmox": {
      "command": "python",
      "args": ["-m", "proxmox_mcp"],
      "env": {
        "PROXMOX_HOST": "https://<IP_PROXMOX>:8006",
        "PROXMOX_USER": "<USER>@<REALM>",
        "PROXMOX_TOKEN_ID": "<USER>@<REALM>!<TOKEN_ID>",
        "PROXMOX_TOKEN_SECRET": "<VOTRE_SECRET_UUID>",
        "VERIFY_SSL": "false"
      }
    }
  }
}
```

### Exemple de configuration remplie
```json
"env": {
  "PROXMOX_HOST": "https://192.168.50.11:8006",
  "PROXMOX_USER": "root@pam",
  "PROXMOX_TOKEN_ID": "root@pam!antigravity",
  "PROXMOX_TOKEN_SECRET": "5f4dcc3b-5aa0-4444-9090-e245645666",
  "VERIFY_SSL": "false"
}
```

## 4. Utilisation

Une fois l'IDE redémarré, l'IA aura accès aux outils exposés par le serveur. Vous pourrez demander en langage naturel :

*   "Liste les VMs éteintes"
*   "Démarre le noeud worker-01"
*   "Donne-moi le statut du stockage local"
