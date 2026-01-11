resource "proxmox_vm_qemu" "haproxy" {
  name        = "haproxy-lb"
  target_node = var.target_node
  clone       = var.template_name
  full_clone  = true

  # --- RESSOURCES SYSTÈME ---
  agent   = 1 # Nécessaire pour que Proxmox remonte l'IP à Tofu
  cores   = 2
  sockets = 1
  memory  = 2048
  scsihw  = "virtio-scsi-pci"
  boot    = "order=scsi0;ide2"

  # --- CONFIGURATION GRAPHIQUE ---
  # Utile si tu veux accéder à la console "NoVNC" via Proxmox en secours
  vga {
    type = "std"
  }

  # Clavier FR (via arguments QEMU)
  args = "-k fr"

  serial {
    id   = 0
    type = "socket"
  }

  # --- RÉSEAU ---
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr1" # Vérifie bien que c'est vmbr1 et pas vmbr0 chez toi
  }

  # --- STOCKAGE ---
  disk {
    slot    = "scsi0"
    storage = "local"
    type    = "disk"
    size    = "20G"
    # format  = "qcow2" # Indispensable sur stockage 'local'
  }

  lifecycle {
    ignore_changes = [
      disk,
      # network, # On veut que Tofu puisse corriger le réseau
      # ipconfig0, # On veut que Tofu puisse corriger l'IP
    ]
  }

  # Lecteur Cloud-Init
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local"
    #format  = "qcow2"
  }

  # --- CLOUD-INIT CONFIG ---
  os_type = "cloud-init"

  # Configuration IP
  ipconfig0  = "ip=${var.haproxy_ip}/24,gw=${var.gateway_ip}"
  nameserver = "1.1.1.1"

  # Utilisateur et Auth
  ciuser     = var.ha_proxy_vm_user
  cipassword = var.ha_proxy_vm_password
  # On injecte ta clé publique (définie dans variables.tf)
  sshkeys = <<EOF
  ${var.ssh_public_key}
  EOF

  # --- ATTENTE DU DÉMARRAGE (SSH CHECK) ---
  provisioner "remote-exec" {
    # Cette commande ne fait rien d'autre que valider que le SSH répond
    inline = ["echo '✅ SSH is ready on HAProxy VM!'"]

    connection {
      type = "ssh"
      user = var.ha_proxy_vm_user # Doit correspondre au ciuser ci-dessus

      # ⚠️ IMPORTANT : Chemin vers ta clé PRIVÉE locale (sur ta machine Windows/GitBash)
      # Assure-toi que ce fichier existe bien : ~/.ssh/id_ed25519
      private_key = file("~/.ssh/id_ed25519")

      host = self.default_ipv4_address
    }
  }
}
