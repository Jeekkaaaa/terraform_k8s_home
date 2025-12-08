terraform {
  required_version = ">= 1.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc06"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

# Генерация случайного MAC-адреса для ВМ
resource "random_integer" "mac_part1" {
  min = 0
  max = 255
}

resource "random_integer" "mac_part2" {
  min = 0
  max = 255
}

resource "random_integer" "mac_part3" {
  min = 0
  max = 255
}

# Функция для поиска свободного VMID
data "external" "next_vmid" {
  program = ["bash", "-c", <<-EOT
    base_id=4000
    max_id=4099
    
    # Проверяем через qm list (проще чем pvesh)
    for i in $(seq $base_id $max_id); do
      if ! qm status $i 2>/dev/null; then
        echo "{\"next_vmid\": \"$i\"}"
        exit 0
      fi
    done
    
    # Если все заняты, берем следующий после максимального
    last_id=$(qm list | tail -n +2 | awk '{print $1}' | sort -n | tail -1)
    next_id=$((last_id + 1))
    
    # Если next_id выходит за пределы диапазона, берем случайный
    if [ $next_id -gt $max_id ]; then
      next_id=$(( base_id + RANDOM % (max_id - base_id + 1) ))
    fi
    
    echo "{\"next_vmid\": \"$next_id\"}"
  EOT
]
}

# Основная ВМ
resource "proxmox_vm_qemu" "k8s_master" {
  name        = "k8s-master-${data.external.next_vmid.result.next_vmid}"
  target_node = var.target_node
  vmid        = tonumber(data.external.next_vmid.result.next_vmid)
  description = "Мастер-нода кластера Kubernetes (случайный MAC, авто-VMID)"
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

  # Сеть со случайным MAC-адресом
  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
    # Случайный MAC-адрес (формат QEMU: 52:54:00:xx:xx:xx)
    macaddr = format("52:54:00:%02x:%02x:%02x",
      random_integer.mac_part1.result,
      random_integer.mac_part2.result,
      random_integer.mac_part3.result)
  }

  # Cloud-Init настройки
  ciuser     = "ubuntu"
  sshkeys    = file(var.ssh_public_key_path)
  ipconfig0  = "ip=dhcp"
  nameserver = "8.8.8.8"
  
  # Агент
  agent = 1

  # Контроллер SCSI
  scsihw = "virtio-scsi-pci"

  # Ожидание DHCP
  provisioner "local-exec" {
    command = "echo 'Ждём получения IP через DHCP...' && sleep 60"
  }

  # Обновление агента через SSH
  provisioner "remote-exec" {
    inline = [
      "echo 'Настройка ВМ...'",
      "sudo apt update",
      "sudo apt install -y qemu-guest-agent 2>/dev/null || echo 'Агент уже установлен'",
      "sudo systemctl start qemu-guest-agent 2>/dev/null || true",
      "echo 'Готово. IP: $(hostname -I)'"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = self.default_ipv4_address
      timeout     = "10m"
      bastion_host = null
      agent        = false
    }
    
    on_failure = continue
  }

  # Очистка SSH known_hosts для нового IP
  provisioner "local-exec" {
    command = <<-EOT
      sleep 30
      if [ -n "${self.default_ipv4_address}" ]; then
        ssh-keygen -f '/root/.ssh/known_hosts' -R "${self.default_ipv4_address}" 2>/dev/null || true
        echo "Очищен known_hosts для ${self.default_ipv4_address}"
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
      disk[1],
      # Игнорируем изменения MAC после создания
      network[0].macaddr
    ]
    
    # Принудительно пересоздаём при изменении VMID
    create_before_destroy = true
  }
}
