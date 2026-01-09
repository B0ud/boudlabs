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
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local"
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
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y haproxy",
    ]
  }

  # Provision the templated config
  provisioner "file" {
    content     = templatefile("${path.module}/haproxy.cfg.tftpl", { worker_ips = var.worker_ips })
    destination = "/tmp/haproxy.cfg"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg",
      "sudo systemctl restart haproxy"
    ]
  }
}
