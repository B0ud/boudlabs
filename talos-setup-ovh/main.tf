variable "proxmox_password" {
  type      = string
  sensitive = true # Empêche Terraform d'afficher le mot de passe dans les logs
}

variable "proxmox_user" {
  type = string
}

variable "proxmox_api_url" {
  type = string
}

terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07" # Version stable courante
    }
  }
}
provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}


# =================================================================
# LISTE DES NŒUDS (C'est ici que tu ajoutes/enlèves des VMs)
# =================================================================
locals {
  nodes = {
    "master-01" = { ip = "192.168.50.110", core = 4, mem = 4096 }
    "master-02" = { ip = "192.168.50.111", core = 4, mem = 4096 }
    "master-03" = { ip = "192.168.50.112", core = 4, mem = 4096 }
    "worker-01" = { ip = "192.168.50.120", core = 4, mem = 8192 } # Plus gros pour les workers
    "worker-02" = { ip = "192.168.50.121", core = 4, mem = 8192 }
    "worker-03" = { ip = "192.168.50.122", core = 4, mem = 8192 }
  }

  gateway       = "192.168.50.1"
  template_name = "talos-template-factory" # Le nom de ton template créé plus tôt
  target_node   = "boudlabs"               # Le nom de ton serveur physique Proxmox
}


# =================================================================
# CRÉATION DES VMS
# =================================================================
resource "proxmox_vm_qemu" "talos_nodes" {
  for_each = local.nodes # La boucle magique !

  name        = each.key
  target_node = local.target_node
  clone       = local.template_name

  # C'est ce bloc qui active l'écran pour la console VNC
  vga {
    type = "std"
  }

  # Tu peux garder ça si tu veux, ou l'enlever. 
  # Le laisser permet d'avoir le VNC ET les logs série si besoin.
  serial {
    id   = 0
    type = "socket"
  }

  # Configuration Hardware
  cpu {
    cores = each.value.core
  }
  memory = each.value.mem
  scsihw = "virtio-scsi-pci"
  boot   = "order=scsi0"
  agent  = 1 # Active l'agent QEMU

  # Disque dur
  disk {
    slot    = "scsi0"
    storage = "local" # Ou "local", selon ton stockage
    type    = "disk"
    size    = "100G" # Taille du disque
  }

  # Réseau (Pont vmbr1)
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr1"
  }

  # ==========================================
  # CLOUD-INIT (C'est ça qui remplace ta config manuelle)
  # ==========================================

  # 👇 AJOUTE CETTE LIGNE OBLIGATOIRE 👇
  cloudinit_cdrom_storage = "local"

  os_type    = "cloud-init"
  ipconfig0  = "ip=${each.value.ip}/24,gw=${local.gateway}"
  nameserver = "1.1.1.1"

  # Important pour que Talos attende bien d'être up
  start_at_node_boot = true
}
