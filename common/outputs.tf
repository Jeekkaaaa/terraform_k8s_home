# Выводим ВСЕ переменные как выходные данные модуля
output "pm_api_url" {
  value = var.pm_api_url
  sensitive = true
}
output "pm_api_token_id" {
  value = var.pm_api_token_id
  sensitive = true
}
output "pm_api_token_secret" {
  value = var.pm_api_token_secret
  sensitive = true
}
output "target_node" {
  value = var.target_node
}
output "ssh_public_key_path" {
  value = var.ssh_public_key_path
}
output "ssh_private_key_path" {
  value = var.ssh_private_key_path
}
output "network_config" {
  value = var.network_config
}
output "vmid_ranges" {
  value = var.vmid_ranges
}
output "cluster_config" {
  value = var.cluster_config
}
output "auto_static_ips" {
  value = var.auto_static_ips
}
output "static_ip_base" {
  value = var.static_ip_base
}
output "vm_specs" {
  value = var.vm_specs
}
output "cloud_init" {
  value = var.cloud_init
}
