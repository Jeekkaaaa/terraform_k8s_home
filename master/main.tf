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
    slot    = 0
    size    = "50G"
    storage = "big_oleg"
    type    = "scsi"
    format  = "raw"
  }

  # Cloud-Init диск (КРИТИЧЕСКИ ВАЖЕН!)
  disk {
    slot    = 2
    storage = "big_oleg"
    type    = "cdrom"
    size    = "4M"
    format  = "raw"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Cloud-Init настройки
  os_type    = "cloud-init"
  ciuser     = "ubuntu"
  sshkeys    = file(var.ssh_public_key_path)
  ipconfig0  = "ip=dhcp"
  nameserver = "8.8.8.8"
  
  # Включаем гостевой агент
  agent = 1

  # Ожидание Cloud-Init
  provisioner "local-exec" {
    command = "echo 'Ожидание завершения Cloud-Init...'; sleep 180"
  }

  # Проверка IP через гостевой агент
  provisioner "local-exec" {
    command = <<-EOT
      echo "Проверка гостевого агента..."
      IP=""
      for i in {1..30}; do
        if qm guest cmd 4000 ping >/dev/null 2>&1; then
          echo "Гостевой агент доступен!"
          IP=$(qm guest cmd 4000 network-get-interfaces 2>/dev/null | \
               jq -r '.data[] | ."ip-addresses"[] | select(."ip-address-type"=="ipv4") | ."ip-address"' | \
               grep -v "127.0.0.1" | head -1)
          if [ -n "$IP" ]; then
            echo "Найден IP: $IP"
            echo "$IP" > /tmp/vm-4000-ip.txt
            break
          fi
        fi
        echo "Попытка $i/30: агент ещё не готов..."
        sleep 10
      done
      
      if [ -z "$IP" ]; then
        echo "Предупреждение: IP не найден через гостевой агент"
        echo "Использую поиск по ARP..."
        # Получаем MAC-адрес из конфига
        MAC=$(qm config 4000 | grep 'net0:' | sed "s/.*=//" | cut -d',' -f1)
        IP=$(arp -an | grep -i "$MAC" | grep -oP '\(\K[^)]+')
        if [ -n "$IP" ]; then
          echo "Найден IP через ARP: $IP"
          echo "$IP" > /tmp/vm-4000-ip.txt
        fi
      fi
    EOT
  }

  # Подключение по SSH (динамический IP)
  provisioner "remote-exec" {
    inline = [
      "echo 'ВМ успешно создана!'",
      "hostname",
      "ip addr show"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = fileexists("/tmp/vm-4000-ip.txt") ? file("/tmp/vm-4000-ip.txt") : self.default_ipv4_address
      timeout     = "10m"
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  lifecycle {
    ignore_changes = [
      disk[1],  # Cloud-Init диск
      ciuser,
      sshkeys,
      ipconfig0,
      nameserver,
      agent
    ]
  }
}

output "vm_ip_address" {
  value = proxmox_vm_qemu.k8s_master.default_ipv4_address
  description = "IP-адрес ВМ через гостевой агент"
  depends_on = [proxmox_vm_qemu.k8s_master]
}

output "vm_status" {
  value = "Создана: ${proxmox_vm_qemu.k8s_master.name} (VMID: ${proxmox_vm_qemu.k8s_master.vmid})"
}
