output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
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
