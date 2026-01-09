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

variable "github_owner" {
  description = "GitHub owner of the repository"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "repository_name" {
  description = "Name of the Github repository"
  type        = string
}

variable "github_branch" {
  description = "Branch of the GitHub repository to use for Flux bootstrap"
  type        = string
  default     = "main"
}
