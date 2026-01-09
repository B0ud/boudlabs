provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

provider "talos" {
  # Configuration will be passed via resources
}

provider "helm" {
  kubernetes = {
    host                   = module.talos_cluster.client_configuration.host
    client_certificate     = base64decode(module.talos_cluster.client_configuration.client_certificate)
    client_key             = base64decode(module.talos_cluster.client_configuration.client_key)
    cluster_ca_certificate = base64decode(module.talos_cluster.client_configuration.ca_certificate)
  }
}

#provider "flux" {
#  kubernetes = {
#    host                   = talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.host
#    client_certificate     = base64decode(talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.client_certificate)
#    client_key             = base64decode(talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.client_key)
#    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration.ca_certificate)
#  }
#  git = {
#    url    = "https://github.com/${var.github_owner}/${var.repository_name}.git"
#    branch = var.github_branch
#    http = {
#      username = "git"
#      password = var.github_token
#    }
#  }
#}
