variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type = string
}

variable "target_node" {
  type    = string
  default = "pve-k8s"
}

variable "ssh_public_key_path" {
  type    = string
  default = "/root/.ssh/id_ed25519.pub"
}

variable "cluster_config" {
  type = object({
    masters_count = number
    workers_count = number
    cluster_name  = string
    domain        = string
  })
  default = {
    masters_count = 1
    workers_count = 0
    cluster_name  = "home-k8s"
    domain        = "home.lab"
  }
}

variable "vmid_ranges" {
  type = object({
    masters = object({ start = number, end = number })
    workers = object({ start = number, end = number })
  })
  default = {
    masters = { start = 2000, end = 2009 }
    workers = { start = 2100, end = 2109 }
  }
}

variable "vm_specs" {
  type = object({
    master = object({
      cpu_cores    = number
      cpu_sockets  = number
      memory_mb    = number
      disk_size_gb = number
      disk_storage = string
    })
    worker = object({
      cpu_cores    = number
      cpu_sockets  = number
      memory_mb    = number
      disk_size_gb = number
      disk_storage = string
    })
  })
  default = {
    master = {
      cpu_cores    = 2
      cpu_sockets  = 1
      memory_mb    = 2048
      disk_size_gb = 20
      disk_storage = "local-lvm"
    }
    worker = {
      cpu_cores    = 2
      cpu_sockets  = 1
      memory_mb    = 2048
      disk_size_gb = 20
      disk_storage = "local-lvm"
    }
  }
}

variable "network_config" {
  type = object({
    subnet       = string
    gateway      = string
    dns_servers  = list(string)
    bridge       = string
  })
  default = {
    subnet       = "192.168.0.0/24"
    gateway      = "192.168.0.1"
    dns_servers  = ["8.8.8.8"]
    bridge       = "vmbr0"
  }
}

variable "cloud_init" {
  type = object({
    user           = string
    search_domains = list(string)
  })
  default = {
    user           = "ubuntu"
    search_domains = ["home.lab"]
  }
}

variable "auto_static_ips" {
  type    = bool
  default = true
}

variable "static_ip_base" {
  type    = number
  default = 110
}
