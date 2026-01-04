# Installation de Talos Linux

Talos Linux est un OS minimaliste et immuable pour Kubernetes. Il tourne entièrement en RAM.

> [!TIP]
> **Setup Avancé / GitOps**
> Pour une gestion déclarative recommandée (avec Talhelper et SOPS), consultez le guide dédié : **[Guide Talhelper & SOPS](talos_talhelper.md)**.
> La méthode ci-dessous décrit l'approche manuelle standard.

## 1. Création de la VM dans Proxmox

> [!TIP]
> **Automatisation (Terraform/OpenTofu)**
> Plutôt que de créer les VMs à la main comme décrit ci-dessous, nous recommandons d'utiliser Terraform.
> Voir le guide : **[Provisioning avec OpenTofu](terraform_proxmox.md)**.

### Méthode Manuelle
1. **Télécharger l'ISO** : Récupérer la dernière image `metal-amd64.iso` sur le GitHub de [siderolabs/talos](https://github.com/siderolabs/talos/releases).
2. **Uploader l'ISO** dans Proxmox.
3. **Créer une VM** :
   - **OS**: Do not use any media (nous allons configurer l'ISO après) ou sélectionner l'ISO Talos. Type: Linux, Kernel 6.x.
   - **System**: Laisser par défaut (Graphics Standard VGA, Machine q35 est recommandé mais i440fx marche aussi). Cocher **Qemu Agent**.
   - **Disks**: SCSI/VirtIO Block, taille min 10GB.
   - **CPU**: Host type, 2 coeurs min.
   - **Memory**: 2048 MB min.
   - **Network**: VirtIO (par bridge `vmbr0`).

## 2. Configuration Talos (Client Side)

Sur votre machine locale (connectée au VPN WireGuard), installez `talosctl`.

### Générer la configuration
```bash
talosctl gen config "boud-cluster" https://<IP_INTERNE_VM_TALOS>:6443
```
*Si la VM Talos n'a pas d'IP publique, elle en aura une via le DHCP de Proxmox ou il faut la configurer statiquement via kernel args au boot.*

### Bootstrapping
Démarrer la VM sur l'ISO. Talos va booter en "Maintenance Mode" en attendant la config.

Appliquer la configuration de contrôle plane :
```bash
talosctl apply-config --insecure -n <IP_INTERNE_VM_TALOS> --file controlplane.yaml
```

Une fois la config appliquée, Talos s'installe sur le disque et reboot.

### Bootstrap Kubernetes
```bash
talosctl bootstrap -n <IP_INTERNE_VM_TALOS> -e <IP_INTERNE_VM_TALOS>
```

## 3. Récupérer le kubeconfig
```bash
talosctl kubeconfig -n <IP_INTERNE_VM_TALOS> .
```

Vous pouvez maintenant utiliser `kubectl` pour interagir avec votre cluster, en passant par le tunnel WireGuard.
