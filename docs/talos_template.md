# Création du Template Talos pour Proxmox

Pour que Terraform puisse injecter les adresses IP statiques via Cloud-Init, il est impératif d'utiliser une **image disque "nocloud"** et non l'ISO d'installation standard.

## Pourquoi cette méthode ?
L'ISO standard de Talos ignore les configurations Cloud-Init de Proxmox. L'image "Factory nocloud" est spécialement conçue pour lire la configuration Cloud-Init (IP, Gateway, DNS) fournie par Proxmox/Terraform.

## Script de Création

Connectez-vous à votre shell Proxmox (via SSH ou Console) et exécutez ce script pour créer le template.

**Note** : Vérifiez la variable `BRIDGE` (ici `vmbr1` pour notre réseau privé).

```bash
# --- CONFIGURATION ---
# L'URL exacte de l'image Factory (version nocloud-amd64.raw.xz)
IMAGE_URL="https://factory.talos.dev/image/dc2c29fc8374161b858245a14658779154bf11aa9c23a04813fa8f298fcd0bfc/v1.12.0/nocloud-amd64.raw.xz"

VM_ID="9000"
VM_NAME="talos-template-factory"
STORAGE="local"   # Mettre "local-lvm" si vous utilisez LVM
BRIDGE="vmbr1"    # Votre Pont Réseau Privé

# --- TÉLÉCHARGEMENT ---
cd /tmp
echo "Téléchargement de l'image Factory..."
wget $IMAGE_URL -O talos.raw.xz

# --- DÉCOMPRESSION ---
echo "Décompression de l'image..."
xz -d -f talos.raw.xz

# --- CRÉATION DE LA VM ---
echo "Création de la VM $VM_ID..."
qm create $VM_ID --name $VM_NAME --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE

# --- IMPORT DU DISQUE ---
echo "Import du disque vers $STORAGE..."
qm importdisk $VM_ID talos.raw $STORAGE

# --- CONFIGURATION MATÉRIELLE ---
# On attache le disque importé
qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:$VM_ID/vm-$VM_ID-disk-0.raw

# Définir l'ordre de boot
qm set $VM_ID --boot c --bootdisk scsi0

# --- CLOUD-INIT & SÉRIE ---
# Ajout du lecteur Cloud-Init (indispensable pour Terraform)
qm set $VM_ID --ide2 $STORAGE:cloudinit
# Console série (utile pour les logs Talos)
qm set $VM_ID --serial0 socket --vga serial0

# --- ACTIVATION DE L'AGENT ---
# L'image Factory contient déjà l'agent QEMU
qm set $VM_ID --agent enabled=1

# --- CONVERSION EN TEMPLATE ---
echo "Transformation en template..."
qm template $VM_ID

# --- NETTOYAGE ---
rm talos.raw
echo "Terminé ! Le template ID $VM_ID ($VM_NAME) est prêt."
```

Une fois ce script terminé, vous aurez un template ID `9000` visible dans Proxmox, prêt à être cloné par Terraform.
