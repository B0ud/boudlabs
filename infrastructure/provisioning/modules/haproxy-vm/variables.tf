variable "target_node" {
  description = "Proxmox Node Name"
  type        = string
}

variable "template_name" {
  description = "Name of the Proxmox Template"
  type        = string
}

variable "gateway_ip" {
  description = "Gateway IP for the VM Network"
  type        = string
}

variable "haproxy_ip" {
  description = "Static IP for HAProxy VM"
  type        = string
  default     = "192.168.50.200"
}

variable "worker_ips" {
  description = "List of Worker Node IPs to load balance"
  type        = list(string)
}

variable "ha_proxy_vm_user" {
  type = string
}

variable "ha_proxy_vm_password" {
  type      = string
  sensitive = true
}

variable "ssh_public_key" {
  type = list(string)
}
