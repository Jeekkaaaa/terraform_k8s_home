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

  # Cloud-Init диск (важно: без format, storage указывает где создавать образ)
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
  
  # Гостевой агент (1 = enabled)
  agent = 1

  # Даём время на загрузку и получение DHCP
  provisioner "local-exec" {
    command = "echo 'Ожидание загрузки ВМ и получения IP...'; sleep 180"
  }

  # Получаем IP через ARP (fallback если агент не работает сразу)
  provisioner "local-exec" {
    command = <<-EOT
      echo "Поиск IP через ARP..."
      sleep 30
      
      # Получаем MAC из конфига ВМ
      MAC=$(qm config 4000 | grep 'net0:' | cut -d'=' -f2 | cut -d',' -f1)
      
      # Ищем IP в ARP таблице
      for i in {1..10}; do
        IP=$(arp -an | grep -i "$MAC" | grep -oP '\(\K[^)]+' | head -1)
        if [ -n "$IP" ]; then
          echo "Найден IP: $IP"
          echo "$IP" > /tmp/vm-4000-ip.txt
          
          # Пробуем установить агент через SSH
          ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            -i ${var.ssh_private_key_path} ubuntu@$IP \
            "sudo apt update && sudo apt install -y qemu-guest-agent && sudo systemctl enable --now qemu-guest-agent" 2>/dev/null || true
          break
        fi
        echo "Попытка $i: IP не найден, ждём 10 секунд..."
        sleep 10
      done
      
      if [ -z "$IP" ]; then
        echo "Внимание: IP не найден через ARP"
        echo "Подключитесь к ВМ через VNC и установите qemu-guest-agent вручную"
      fi
    EOT
  }

  # Проверка SSH (после установки агента)
  provisioner "remote-exec" {
    inline = [
      "echo '=== ВМ k8s-master-01 готова ==='",
      "echo 'Версия Ubuntu:'",
      "lsb_release -a 2>/dev/null || echo 'lsb_release не установлен'",
      "echo 'IP адреса:'",
      "ip -4 addr show | grep inet"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = fileexists("/tmp/vm-4000-ip.txt") ? file("/tmp/vm-4000-ip.txt") : self.default_ipv4_address
      timeout     = "10m"
    }
    
    on_failure = continue
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
      disk[1]  # Cloud-Init диск
    ]
  }
}

output "vm_status" {
  value = "ВМ ${proxmox_vm_qemu.k8s_master.name} создана (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}

output "vm_ip" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
  description = "IP адрес через гостевой агент (может быть пустым если агент не работает)"
}

output "check_commands" {
  value = <<-EOT
    Команды для проверки:
    1. Проверить Cloud-Init: qm config 4000 | grep ide2
    2. Проверить агент: qm guest cmd 4000 ping
    3. Проверить IP: qm guest cmd 4000 network-get-interfaces
    4. Если агент не работает: 
       - Зайдите через VNC: sudo apt install qemu-guest-agent
       - Или через SSH: ssh ubuntu@<IP>
  EOT
}
