variable "proxmox_api_url" {
  type = string
}

variable "proxmox_user" {
  type = string
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}

variable "github_owner" {
  type = string
}

variable "github_token" {
  type      = string
  sensitive = true
}

variable "repository_name" {
  type = string
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "ha_proxy_vm_user" {
  description = "User for HAProxy VM"
  type        = string
}

variable "ha_proxy_vm_password" {
  description = "Password for HAProxy VM"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "List of Public SSH keys to inject into VMs"
  type        = list(string)
}
