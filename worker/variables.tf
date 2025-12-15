# Подключаем общий модуль для получения переменных
module "common_config" {
  source = "../common"
}

# Локальные переменные модуля master, получающие значения из common
variable "pm_api_url" {
  type      = string
  sensitive = true
  default   = module.common_config.pm_api_url
}
variable "pm_api_token_id" {
  type      = string
  sensitive = true
  default   = module.common_config.pm_api_token_id
}
variable "pm_api_token_secret" {
  type      = string
  sensitive = true
  default   = module.common_config.pm_api_token_secret
}
variable "target_node" {
  type    = string
  default = module.common_config.target_node
}
variable "ssh_public_key_path" {
  type    = string
  default = module.common_config.ssh_public_key_path
}
variable "ssh_private_key_path" {
  type    = string
  default = module.common_config.ssh_private_key_path
}
variable "network_config" {
  type = object({
    subnet       = string
    gateway      = string
    dns_servers  = list(string)
    bridge       = string
    dhcp_start   = number
    dhcp_end     = number
  })
  default = module.common_config.network_config
}
variable "vmid_ranges" {
  type = object({
    masters = object({ start = number, end = number })
    workers = object({ start = number, end = number })
  })
  default = module.common_config.vmid_ranges
}
variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
  })
  default = module.common_config.cluster_config
}
variable "auto_static_ips" {
  type    = bool
  default = module.common_config.auto_static_ips
}
variable "static_ip_base" {
  type    = number
  default = module.common_config.static_ip_base
}
variable "vm_specs" {
  type = object({
    master = object({
      cpu_cores    = number
      cpu_sockets  = number
      memory_mb    = number
      disk_size_gb = number
      disk_storage = string
      disk_format  = string
    })
    worker = object({
      cpu_cores    = number
      cpu_sockets  = number
      memory_mb    = number
      disk_size_gb = number
      disk_storage = string
      disk_format  = string
    })
  })
  default = module.common_config.vm_specs
}
variable "cloud_init" {
  type = object({
    user           = string
    search_domains = list(string)
  })
  default = module.common_config.cloud_init
}
