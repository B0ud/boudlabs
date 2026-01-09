output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}

output "client_configuration" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubernetes_client_configuration
  sensitive = true
}

output "talosconfig" {
  value     = data.local_file.talosconfig.content
  sensitive = true
}

output "control_plane_vip" {
  description = "L'IP virtuelle pour accéder à l'API Server"
  value       = "https://192.168.50.100:6443"
}

output "nodes_configured" {
  description = "Liste des noeuds provisionnés"
  value       = [for name, config in local.nodes : "${name} - ${config.ip}"]
}

output "worker_ips" {
  description = "List of Worker Node IPs for Load Balancing"
  value       = [for name, config in local.nodes : config.ip if can(regex("worker", name))]
}
