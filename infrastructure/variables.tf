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
