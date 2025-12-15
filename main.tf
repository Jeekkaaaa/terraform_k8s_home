terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

locals {
  # Создаём список индексов [0, 1, 2] для трёх машин (или сколько задано)
  master_indices = range(var.cluster_config.masters_count)
}

# Мастер-ноды. Создаётся по одной на каждый индекс.
resource "proxmox_vm_qemu" "k8s_master" {
  for_each = { for idx in local.master_indices : idx => idx }

  name        = "k8s-master-${var.vmid_ranges.masters.start + each.key}"
  target_node = var.target_node
  vmid        = var.vmid_ranges.masters.start + each.key
  description = "Мастер-нода ${each.key + 1} кластера ${var.cluster_config.cluster_name}"
  start_at_node_boot = true

  cpu {
    cores   = var.vm_specs.master.cpu_cores
    sockets = var.vm_specs.master.cpu_sockets
  }
  memory = var.vm_specs.master.memory_mb

  clone      = "ubuntu-template"
  full_clone = true

  disk {
    slot    = "scsi0"
    size    = "${var.vm_specs.master.disk_size_gb}G"
    storage = var.vm_specs.master.disk_storage
    type    = "disk"
    format  = var.vm_specs.master.disk_format
  }
  disk {
    slot    = "ide2"
    storage = var.vm_specs.master.disk_storage
    type    = "cloudinit"
  }
  network {
    id      = 0
    model   = "virtio"
    bridge  = var.network_config.bridge
    macaddr = format("52:54:00:%02x:%02x:%02x",
      floor(self.vmid / 65536) % 256,
      floor(self.vmid / 256) % 256,
      self.vmid % 256)
  }

  ciuser       = var.cloud_init.user
  sshkeys      = file(var.ssh_public_key_path)
  ipconfig0    = var.auto_static_ips ? "ip=${cidrhost(var.network_config.subnet, var.static_ip_base + each.key)}/24,gw=${var.network_config.gateway}" : "ip=dhcp"
  nameserver   = join(" ", var.network_config.dns_servers)
  searchdomain = join(" ", var.cloud_init.search_domains)
  agent        = 1
  scsihw       = "virtio-scsi-pci"

  lifecycle {
    ignore_changes = [
      network[0].macaddr,
      vmid
    ]
  }
}

output "master_instances" {
  value = {
    for idx, vm in proxmox_vm_qemu.k8s_master : idx => {
      name = vm.name
      vmid = vm.vmid
      ip   = var.auto_static_ips ? cidrhost(var.network_config.subnet, var.static_ip_base + idx) : vm.default_ipv4_address
      ssh  = "ssh -o StrictHostKeyChecking=no ${var.cloud_init.user}@${var.auto_static_ips ? cidrhost(var.network_config.subnet, var.static_ip_base + idx) : vm.default_ipv4_address}"
    }
  }
}
