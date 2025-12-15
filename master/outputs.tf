output "master_instances" {
  description = "Информация о всех созданных мастер-нодах"
  value = {
    for idx, vm in proxmox_vm_qemu.k8s_master : idx => {
      name = vm.name
      vmid = vm.vmid
      ip   = var.auto_static_ips ? cidrhost(var.network_config.subnet, var.static_ip_base + idx) : vm.default_ipv4_address
      ssh  = "ssh -o StrictHostKeyChecking=no ${var.cloud_init.user}@${var.auto_static_ips ? cidrhost(var.network_config.subnet, var.static_ip_base + idx) : vm.default_ipv4_address}"
    }
  }
}
