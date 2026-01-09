terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07" # Version stable courante
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    #flux = {
    #  source  = "fluxcd/flux"
    #  version = "1.7.6"
    #}
  }
}
