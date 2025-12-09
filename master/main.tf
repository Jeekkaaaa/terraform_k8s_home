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

# Генерация уникальных значений
locals {
  unique_seed = sha256(timestamp())
  vm_id = 4000 + (parseint(substr(local.unique_seed, 0, 2), 16) % 100)
  
  # Генерация MAC
  mac_part1 = parseint(substr(local.unique_seed, 2, 2), 16) % 256
  mac_part2 = parseint(substr(local.unique_seed, 4, 2), 16) % 256
  mac_part3 = parseint(substr(local.unique_seed, 6, 2), 16) % 256
  mac_address = format("52:54:00:%02x:%02x:%02x", 
    local.mac_part1, local.mac_part2, local.mac_part3)
}

# Основная ВМ
resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-${local.vm_id}"
  target_node = var.target_node
  vmid        = local.vm_id
  description = "Мастер-нода Kubernetes (DHCP)"
  start_at_node_boot = true

  cpu {
    cores   = 4
    sockets = 1
  }
  
  memory  = 8192

  clone      = "ubuntu-template"
  full_clone = true

  disk {
    slot    = "scsi0"
    size    = "50G"
    storage = "big_oleg"
    type    = "disk"
    format  = "raw"
  }

  disk {
    slot    = "ide2"
    storage = "big_oleg"
    type    = "cloudinit"
  }

  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    macaddr = local.mac_address
  }

  # Используем DHCP
  ciuser     = "ubuntu"
  sshkeys    = file(var.ssh_public_key_path)
  ipconfig0  = "ip=dhcp"
  nameserver = "8.8.8.8"
  
  agent = 1
  scsihw = "virtio-scsi-pci"

  # ========== КЛЮЧЕВОЕ ИЗМЕНЕНИЕ ==========
  # Разделяем на два этапа
  
  # Этап 1: Ждем получения первого IP
  provisioner "local-exec" {
    command = "echo 'Ожидание получения IP через DHCP...' && sleep 45"
  }

  # Этап 2: Настройка machine-id БЕЗ перезапуска сети
  provisioner "remote-exec" {
    inline = [
      "echo 'Начинаем настройку...'",
      "echo 'Текущий IP: $(hostname -I)'",
      "echo 'Старый machine-id: $(cat /etc/machine-id 2>/dev/null || echo не найден)'",
      
      # Генерируем новый machine-id но НЕ перезапускаем сеть!
      "sudo rm -f /etc/machine-id /var/lib/dbus/machine-id",
      "sudo dbus-uuidgen --ensure",
      "sudo systemd-machine-id-setup",
      
      # Записываем конфигурацию для СЛЕДУЮЩЕЙ перезагрузки
      "echo 'Настройка netplan для использования MAC как DHCP идентификатора...'",
      "sudo cat > /etc/netplan/99-dhcp-mac.yaml << 'EOF'",
      "network:",
      "  version: 2",
      "  ethernets:",
      "    eth0:",
      "      dhcp4: true",
      "      dhcp-identifier: mac",
      "EOF",
      
      "echo 'Готово. При следующей перезагрузке будет новый machine-id и MAC как DHCP ID.'",
      "echo 'Текущий IP остался: $(hostname -I)'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
      timeout     = "10m"
      agent       = false
    }
    
    # Продолжать даже если SSH оборвется
    on_failure = continue
  }

  # Этап 3: Мягкая перезагрузка (опционально)
  provisioner "local-exec" {
    command = <<-EOT
      echo "Мягкая перезагрузка ВМ ${self.vmid} для применения новых настроек..."
      qm reboot ${self.vmid}
      sleep 60
      echo "Перезагрузка завершена"
    EOT
  }

  lifecycle {
    ignore_changes = [
      network[0].macaddr,
      vmid
    ]
  }
}

# Output переменные
output "vm_info" {
  value = "ВМ ${proxmox_vm_qemu.k8s_master.name} (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}

output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
}

output "ssh_command" {
  value = "ssh -o StrictHostKeyChecking=no ubuntu@${proxmox_vm_qemu.k8s_master.default_ipv4_address}"
}

output "next_steps" {
  value = <<-EOT
    После создания ВМ:
    1. Проверить IP: qm guest exec ${proxmox_vm_qemu.k8s_master.vmid} -- hostname -I
    2. Проверить machine-id: qm guest exec ${proxmox_vm_qemu.k8s_master.vmid} -- cat /etc/machine-id
    3. Перезагрузить для получения нового IP: qm reboot ${proxmox_vm_qemu.k8s_master.vmid}
    
    Новая ВМ получила:
    - Уникальный MAC: ${local.mac_address}
    - Уникальный machine-id
    - Netplan конфиг для использования MAC как DHCP идентификатора
  EOT
}
