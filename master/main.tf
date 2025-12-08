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

resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-01"
  target_node = var.target_node
  vmid        = 4000
  description = "Первая мастер-нода кластера Kubernetes"
  start_at_node_boot = true

  cpu {
    cores   = 4
    sockets = 1
  }
  
  memory  = 8192

  clone      = "ubuntu-template"
  full_clone = true

  # Системный диск
  disk {
    slot    = "scsi0"
    size    = "50G"
    storage = "big_oleg"
    type    = "disk"
    format  = "raw"
  }

  # Cloud-Init диск
  disk {
    slot    = "ide2"
    storage = "big_oleg"
    type    = "cloudinit"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Cloud-Init настройки
  ciuser     = "ubuntu"
  sshkeys    = file(var.ssh_public_key_path)
  ipconfig0  = "ip=dhcp"
  nameserver = "8.8.8.8"
  
  # Агент
  agent = 1

  # Контроллер SCSI как в темплейте
  scsihw = "virtio-scsi-pci"

  # Пост-настройка через local-exec
  provisioner "local-exec" {
    command = <<-EOT
      # 1. Фиксируем темплейт (если не исправлен)
      qm set 9000 --agent enabled=1,fstrim_cloned_disks=1 2>/dev/null || true
      qm template 9000 2>/dev/null || true
      
      # 2. Исправляем агент в новой ВМ
      sleep 30
      qm set 4000 --agent enabled=1,fstrim_cloned_disks=1
      qm reboot 4000
      
      # 3. Очищаем SSH known_hosts
      sleep 30
      IP=$(qm agent 4000 network-get-interfaces 2>/dev/null | grep -o '"192\.168\.[0-9]*\.[0-9]*"' | head -1 | tr -d '"')
      if [ -n "$IP" ]; then
        ssh-keygen -f '/root/.ssh/known_hosts' -R "$IP" 2>/dev/null || true
      fi
    EOT
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  lifecycle {
    ignore_changes = [
      ciuser,
      sshkeys,
      ipconfig0,
      nameserver,
      agent,
      disk[1]
    ]
  }
}

output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
}

output "ssh_command" {
  value = "ssh -o StrictHostKeyChecking=no ubuntu@${proxmox_vm_qemu.k8s_master.default_ipv4_address}"
}
