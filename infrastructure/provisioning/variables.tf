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
