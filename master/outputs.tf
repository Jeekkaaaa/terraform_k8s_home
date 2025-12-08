# outputs.tf
output "k8s_master_ip" {
  value       = proxmox_vm_qemu.k8s_master.default_ipv4_address
  description = "IP-адрес мастер-ноды Kubernetes"
  sensitive   = false # Можно поставить true, чтобы скрыть в логах
}

output "k8s_master_name" {
  value       = proxmox_vm_qemu.k8s_master.name
  description = "Имя мастер-ноды"
}
