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
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.0" # Vérifie la dernière version
    }
  }
}
provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

provider "talos" {
  # Configuration vide au départ, on la passera dans les ressources
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

  talosconfig_data = yamldecode(data.local_file.talosconfig.content)
  talos_context    = local.talosconfig_data.contexts[local.talosconfig_data.context]
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
  boot   = "order=scsi0;ide2"
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
  # Disque Cloud-Init (obligatoire pour stocker la config)
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local"
  }

  os_type    = "cloud-init"
  ipconfig0  = "ip=${each.value.ip}/24,gw=${local.gateway}"
  nameserver = "1.1.1.1"

  # Important pour que Talos attende bien d'être up
  start_at_node_boot = true
}

# =================================================================
# AUTOMATISATION TALHELPER & TALOSCTL
# =================================================================

# 1. Génération automatique de la config (remplace "talhelper genconfig")
resource "terraform_data" "talhelper_gen" {
  # Si talconfig.yaml change, on régénère tout
  triggers_replace = [
    filesha256("talconfig.yaml")
  ]

  provisioner "local-exec" {
    command = "talhelper genconfig"
    environment = {
      SOPS_AGE_KEY_FILE = "d:/Mehdi/Documents/BoudLabs/talos-setup-ovh/age.key.txt"
    }
  }
}

# 2. Lecture des fichiers de configuration générés
# On charge la config machine pour chaque nœud défini dans tes locals
data "local_file" "machine_configs" {
  for_each = local.nodes

  depends_on = [terraform_data.talhelper_gen]
  # Assure-toi que talhelper génère bien les noms sous la forme : proxmox-cluster-<nom-du-noeud>.yaml
  filename = "${path.module}/clusterconfig/proxmox-cluster-${each.key}.yaml"
}

# On charge le talosconfig (nécessaire pour parler au cluster)
data "local_file" "talosconfig" {
  depends_on = [terraform_data.talhelper_gen]
  filename   = "${path.module}/clusterconfig/talosconfig"
}

# 3. Application de la configuration (remplace "taloctl apply-config")
resource "talos_machine_configuration_apply" "node_config_apply" {
  for_each = local.nodes

  depends_on = [
    proxmox_vm_qemu.talos_nodes, # On attend que la VM soit UP
    terraform_data.talhelper_gen # On attend que la config soit générée
  ]

  client_configuration = {
    ca_certificate     = local.talos_context.ca
    client_certificate = local.talos_context.crt
    client_key         = local.talos_context.key
  }
  machine_configuration_input = data.local_file.machine_configs[each.key].content

  # On utilise l'IP définie dans tes variables locals
  node = each.value.ip
}

# 4. Bootstrap du cluster (remplace "taloctl bootstrap")
# On ne le lance que sur le PREMIER nœud maître
resource "talos_machine_bootstrap" "bootstrap" {
  depends_on = [talos_machine_configuration_apply.node_config_apply]

  client_configuration = {
    ca_certificate     = local.talos_context.ca
    client_certificate = local.talos_context.crt
    client_key         = local.talos_context.key
  }
  node = local.nodes["master-01"].ip
}

# 5. Récupération du Kubeconfig final
resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on = [talos_machine_bootstrap.bootstrap]

  client_configuration = {
    ca_certificate     = local.talos_context.ca
    client_certificate = local.talos_context.crt
    client_key         = local.talos_context.key
  }
  node = local.nodes["master-01"].ip
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.local_file.talosconfig.content
  sensitive = true
}

output "control_plane_vip" {
  description = "L'IP virtuelle pour accéder à l'API Server"
  value       = "https://192.168.50.100:6443"
}

output "nodes_configured" {
  description = "Liste des noeuds provisionnés"
  value       = [for name, config in local.nodes : "${name} - ${config.ip}"]
}

check "cluster_health" {
  data "http" "kube_api_health" {
    url      = "https://192.168.50.100:6443/livez"
    insecure = true
    retry {
      attempts     = 10
      min_delay_ms = 1000
      max_delay_ms = 5000
    }
  }

  assert {
    # 200 = OK (Anonymous Auth activé)
    # 401 = Unauthorized (API UP mais Auth requise, ce qui est normal pour Talos sécurisé)
    condition     = contains([200, 401, 403], data.http.kube_api_health.status_code)
    error_message = "L'API Kubernetes n'est pas joignable (Status différent de 200/401/403). VIP: 192.168.50.100"
  }
}
