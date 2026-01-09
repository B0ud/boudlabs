moved {
  from = proxmox_vm_qemu.talos_nodes
  to   = module.talos_cluster.proxmox_vm_qemu.talos_nodes
}

moved {
  from = talos_machine_configuration_apply.node_config_apply
  to   = module.talos_cluster.talos_machine_configuration_apply.node_config_apply
}

moved {
  from = talos_machine_bootstrap.bootstrap
  to   = module.talos_cluster.talos_machine_bootstrap.bootstrap
}

moved {
  from = talos_cluster_kubeconfig.kubeconfig
  to   = module.talos_cluster.talos_cluster_kubeconfig.kubeconfig
}

moved {
  from = data.local_file.talosconfig
  to   = module.talos_cluster.data.local_file.talosconfig
}

moved {
  from = terraform_data.talhelper_gen
  to   = module.talos_cluster.terraform_data.talhelper_gen
}
