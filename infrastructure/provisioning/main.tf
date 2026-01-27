

module "talos_cluster" {
  source = "./modules/talos-cluster"

  proxmox_api_url  = var.proxmox_api_url
  proxmox_user     = var.proxmox_user
  proxmox_password = var.proxmox_password
  github_owner     = var.github_owner
  github_token     = var.github_token
  repository_name  = var.repository_name
  github_branch    = var.github_branch
}

module "haproxy_vm" {
  source = "./modules/haproxy-vm"

  target_node   = "boudlabs"
  template_name = "debian-13-trixie-template" # Changed from talos-template-factory to ensure standard Linux access
  gateway_ip    = "192.168.50.1"
  haproxy_ip    = "192.168.50.200"
  worker_ips    = module.talos_cluster.worker_ips

  ha_proxy_vm_user     = var.ha_proxy_vm_user
  ha_proxy_vm_password = var.ha_proxy_vm_password
  ssh_public_key       = var.ssh_public_key
}

resource "null_resource" "helm_repo" {
  provisioner "local-exec" {
    command = "helm repo add cilium https://helm.cilium.io/ && helm repo update"
  }
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.18.5"
  namespace  = "kube-system"

  # We use depends_on to ensure cluster is ready and repo is updated
  depends_on = [module.talos_cluster, null_resource.helm_repo]

  values = [
    # Verify path relative to ROOT module
    file("${path.module}/../../kubernetes/cilium/values.yaml")
  ]
}

output "kubeconfig" {
  value     = module.talos_cluster.kubeconfig
  sensitive = true
}

output "haproxy_ip" {
  value = module.haproxy_vm.ha_proxy_ip
}
output "worker_ips" {
  value = module.talos_cluster.worker_ips
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

