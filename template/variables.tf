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

# Основные
variable "target_node" {
  type = string
}

variable "template_vmid" {
  type = number
}

variable "ssh_public_key" {
  type = string
}

variable "storage" {
  type = string
}

# Шаблон
variable "template_specs" {
  type = object({
    cpu_cores     = number
    cpu_sockets   = number
    memory_mb     = number
    disk_size_gb  = number
    disk_iothread = bool
  })
}

# Cloud-init
variable "cloud_init" {
  type = object({
    user           = string
    search_domains = list(string)
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
