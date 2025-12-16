# Proxmox API
variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type = string
}

# Основные настройки
variable "target_node" {
  type = string
}

# Шаблон
variable "template_vmid" {
  type = number
}

# SSH ключ
variable "ssh_public_key" {
  type = string
}

# IP база (для совместимости)
variable "static_ip_base" {
  type = number
}

# Конфигурация сети
variable "network_config" {
  type = object({
    subnet       = string
    gateway      = string
    dns_servers  = list(string)
    bridge       = string
  })
}

# Конфигурация кластера
variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
  })
}

# VM ID диапазоны
variable "vmid_ranges" {
  type = object({
    masters = object({ start = number, end = number })
    workers = object({ start = number, end = number })
  })
}

# Спецификации VM
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

# Спецификации шаблона - ВАЖНО: default ЗДЕСЬ!
variable "template_specs" {
  type = object({
    cpu_cores     = number
    cpu_sockets   = number
    memory_mb     = number
    disk_size_gb  = number
    disk_iothread = bool
  })
  default = {
    cpu_cores     = 2
    cpu_sockets   = 1
    memory_mb     = 2048
    disk_size_gb  = 12
    disk_iothread = true
  }
}

# Cloud-init
variable "cloud_init" {
  type = object({
    user           = string
    search_domains = list(string)
  })
}

# Общие настройки
variable "storage" {
  type = string
}

variable "bridge" {
  type = string
}
