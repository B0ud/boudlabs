resource "proxmox_vm_qemu" "haproxy" {
  name        = "haproxy-lb"
  target_node = var.target_node
  clone       = var.template_name
  agent       = 1
  cpu {
    cores = 2
  }
  memory = 2048
  scsihw = "virtio-scsi-pci"
  boot   = "order=scsi0;ide2"

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr1"
  }

  disk {
    slot    = "scsi0"
    storage = "local"
    type    = "disk"
    size    = "20G"
    format  = "qcow2"
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local"
  }

  # Tu peux garder ça si tu veux, ou l'enlever. 
  # Le laisser permet d'avoir le VNC ET les logs série si besoin.
  serial {
    id   = 0
    type = "socket"
  }


  os_type = "cloud-init"

  ipconfig0  = "ip=${var.haproxy_ip}/24,gw=${var.gateway_ip}"
  nameserver = "1.1.1.1"

  ciuser     = "debian"
  cipassword = "password"

  connection {
    type     = "ssh"
    user     = "debian"
    password = "password"
    host     = var.haproxy_ip
  }

  provisioner "remote-exec" {
    inline = ["echo 'SSH is up!'"]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("~/.ssh/id_ed25519") # Chemin vers TA clé privée sur la machine qui lance Tofu
      host        = self.default_ipv4_address
    }
  }

}
