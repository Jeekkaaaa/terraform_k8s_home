# ВСЕ переменные из config.auto.tfvars

# Proxmox
variable "pm_api_url" {}
variable "pm_api_token_id" {}
variable "pm_api_token_secret" {}
variable "proxmox_ssh_username" {}
variable "proxmox_ssh_password" {}

# Основные
variable "target_node" {}
variable "ssh_public_key" {}

# Шаблон
variable "template_vmid" {}
variable "template_specs" {
  type = object({
    cpu_cores     = number
    cpu_sockets   = number
    memory_mb     = number
    disk_size_gb  = number
    disk_iothread = bool
  })
}

# Кластер
variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
  })
}

# VM ID
variable "vmid_ranges" {
  type = object({
    masters = object({ start = number, end = number })
    workers = object({ start = number, end = number })
  })
}

# Спецификации
variable "vm_specs" {
  type = object({
    master = object({
      cpu_cores         = number
      cpu_sockets       = number
      memory_mb         = number
      disk_size_gb      = number
      disk_storage      = string
      disk_iothread     = bool
      cloudinit_storage = string
    })
    worker = object({
      cpu_cores         = number
      cpu_sockets       = number
      memory_mb         = number
      disk_size_gb      = number
      disk_storage      = string
      disk_iothread     = bool
      cloudinit_storage = string
    })
  })
}

# Сеть
variable "network_config" {
  type = object({
    subnet       = string
    gateway      = string
    dns_servers  = list(string)
    bridge       = string
  })
}

# Cloud-init
variable "cloud_init" {
  type = object({
    user           = string
    search_domains = list(string)
  })
}

# IP
variable "static_ip_base" {}

# Хранилища
variable "storage_iso" {}
variable "storage_vm" {}
