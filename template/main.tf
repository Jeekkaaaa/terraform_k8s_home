terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.56.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pm_api_url
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"
  insecure  = true
  
  ssh {
    username = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
  }
}

# 1. УДАЛЯЕМ старый шаблон если есть
resource "terraform_data" "cleanup_old_template" {
  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = regex("//([^:/]+)", var.pm_api_url)[0]
  }

  provisioner "remote-exec" {
    inline = [
      "echo '=== Удаляем старый шаблон 9001 если существует ==='",
      "qm destroy ${var.template_vmid} --purge 2>/dev/null || true",
      "sleep 2",
      "echo 'Старый шаблон удален'"
    ]
  }
}

# 2. Создание ПУСТОЙ ВМ для шаблона
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  depends_on = [terraform_data.cleanup_old_template]
  
  name      = "ubuntu-template"
  node_name = var.target_node
  vm_id     = var.template_vmid
  started   = false

  cpu {
    cores   = var.template_specs.cpu_cores
    sockets = var.template_specs.cpu_sockets
  }

  memory {
    dedicated = var.template_specs.memory_mb
  }

  # Минимальный диск для создания ВМ
  disk {
    datastore_id = var.storage_vm
    size         = 1
    interface    = "scsi0"
    file_format  = "raw"
  }

  initialization {
    datastore_id = var.storage_vm

    user_account {
      username = var.cloud_init.user
      keys     = [var.ssh_public_key]
    }

    dns {
      servers = var.network_config.dns_servers
      domain  = var.cloud_init.search_domains[0]
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  network_device {
    bridge = var.network_config.bridge
    model  = "virtio"
  }

  agent {
    enabled = true
  }

  template = false
}

# 3. SSH команды для создания ПРАВИЛЬНОГО шаблона
resource "terraform_data" "create_proper_template" {
  depends_on = [proxmox_virtual_environment_vm.ubuntu_template]

  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = regex("//([^:/]+)", var.pm_api_url)[0]
    timeout  = "1200s"
  }

  provisioner "remote-exec" {
    inline = [
      "set -ex",  # Выход при любой ошибке
      
      "echo '=== Шаг 1: Скачиваем Ubuntu Cloud образ ==='",
      "cd /var/lib/vz/template/iso/",
      "if [ ! -f jammy-server-cloudimg-amd64.img ]; then",
      "  echo 'Скачиваем...'",
      "  wget -q --show-progress https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img",
      "fi",
      
      "echo '=== Шаг 2: Удаляем временный диск 1GB ==='",
      "qm set ${var.template_vmid} --delete scsi0 2>/dev/null || true",
      "sleep 2",
      
      "echo '=== Шаг 3: Импортируем Cloud-образ как RAW диск ==='",
      "qm importdisk ${var.template_vmid} jammy-server-cloudimg-amd64.img ${var.storage_vm} --format raw",
      
      "echo '=== Шаг 4: Подключаем импортированный диск как scsi0 ==='",
      "qm set ${var.template_vmid} --scsi0 ${var.storage_vm}:vm-${var.template_vmid}-disk-0",
      
      "echo '=== Шаг 5: Устанавливаем размер диска ${var.template_specs.disk_size_gb}GB ==='",
      "qm resize ${var.template_vmid} scsi0 ${var.template_specs.disk_size_gb}G",
      
      "echo '=== Шаг 6: Настраиваем загрузку ==='",
      "qm set ${var.template_vmid} --boot order=scsi0",
      "qm set ${var.template_vmid} --scsihw virtio-scsi-pci",
      
      "echo '=== Шаг 7: Конвертируем в шаблон ==='",
      "qm template ${var.template_vmid}",
      
      "echo '=== Шаг 8: Проверяем шаблон ==='",
      "qm config ${var.template_vmid} | grep -E '(scsi0|boot|template)'",
      
      "echo '✅ Шаблон ${var.template_vmid} создан правильно!'"
    ]
  }
}

output "template_ready" {
  value = "Template ${var.template_vmid} created with Cloud image"
  depends_on = [terraform_data.create_proper_template]
}
