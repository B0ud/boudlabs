# =================================================================
# LISTE DES NŒUDS (C'est ici que tu ajoutes/enlèves des VMs)
# =================================================================
locals {
  nodes = {
    "master-01" = { ip = "192.168.50.110", core = 4, mem = 8192 }
    "master-02" = { ip = "192.168.50.111", core = 4, mem = 8192 }
    "master-03" = { ip = "192.168.50.112", core = 4, mem = 8192 }
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

  lifecycle {
    ignore_changes = [
      disk,
      network,
      startup_shutdown,
      boot,
      ipconfig0,
    ]
  }
}

# =================================================================
# AUTOMATISATION TALHELPER & TALOSCTL
# =================================================================

# 1. Génération automatique de la config (remplace "talhelper genconfig")
resource "terraform_data" "talhelper_gen" {
  # Si talconfig.yaml change, on régénère tout
  triggers_replace = [
    filesha256("${path.module}/../../../../talos/talconfig.yaml")
  ]

  provisioner "local-exec" {
    command = "talhelper genconfig -c ../../talos/talconfig.yaml -s ../../talos/talsecret.sops.yaml -o ../../talos/clusterconfig"
    environment = {
      SOPS_AGE_KEY_FILE = abspath("../../talos/age.key.txt")
    }
    # Working dir stays default (infrastructure), we use relative paths in command
  }
}

# 2. Lecture des fichiers de configuration générés
# On charge la config machine pour chaque nœud défini dans tes locals
data "local_file" "machine_configs" {
  for_each = local.nodes

  depends_on = [terraform_data.talhelper_gen]
  # Assure-toi que talhelper génère bien les noms sous la forme : proxmox-cluster-<nom-du-noeud>.yaml
  filename = "${path.module}/../../../../talos/clusterconfig/proxmox-cluster-${each.key}.yaml"
}

# On charge le talosconfig (nécessaire pour parler au cluster)
data "local_file" "talosconfig" {
  depends_on = [terraform_data.talhelper_gen]
  filename   = "${path.module}/../../../../talos/clusterconfig/talosconfig"
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




#resource "flux_bootstrap_git" "this" {
#  depends_on = [helm_release.cilium]
#
#
#  path = abspath("${path.module}/../gitops")
#
#  components_extra = [
#    "image-reflector-controller",
#    "image-automation-controller",
#  ]
#}
