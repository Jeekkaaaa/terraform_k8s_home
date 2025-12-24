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

# 1. Создание пустой ВМ с минимальным диском
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
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

  # Временный диск (RAW формат для LVM)
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
    type    = "virtio"
  }

  template = false

  lifecycle {
    ignore_changes = [
      disk[0].size,
      network_device,
    ]
  }
}

# 2. Скачивание образа и импорт
resource "terraform_data" "download_and_import_image" {
  depends_on = [proxmox_virtual_environment_vm.ubuntu_template]

  triggers_replace = {
    vm_id = var.template_vmid
    timestamp = timestamp()
  }

  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = regex("//([^:/]+)", var.pm_api_url)[0]
    timeout  = "600s"  # 10 минут таймаут
  }

  provisioner "remote-exec" {
    inline = [
      "echo '=== Шаг 1: Ждем стабилизации ВМ ${var.template_vmid} ==='",
      "sleep 10",
      
      "echo '=== Шаг 2: Скачиваем Cloud-образ ==='",
      "cd /var/lib/vz/template/iso/",
      "if [ ! -f jammy-server-cloudimg-amd64.img ]; then",
      "  wget -q -O jammy-server-cloudimg-amd64.img.tmp https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img || \\",
      "  curl -L -o jammy-server-cloudimg-amd64.img.tmp https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img",
      "  mv jammy-server-cloudimg-amd64.img.tmp jammy-server-cloudimg-amd64.img",
      "  echo 'Образ скачан'",
      "else",
      "  echo 'Образ уже существует'",
      "fi",
      
      "echo '=== Шаг 3: Проверяем что ВМ существует ==='",
      "qm status ${var.template_vmid} || exit 1",
      "sleep 5",
      
      "echo '=== Шаг 4: Удаляем временный диск ==='",
      "qm set ${var.template_vmid} --delete scsi0 2>/dev/null || true",
      "sleep 2",
      
      "echo '=== Шаг 5: Импортируем Cloud-образ ==='",
      "qm importdisk ${var.template_vmid} /var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img ${var.storage_vm} --format raw",
      "sleep 5",
      
      "echo '=== Шаг 6: Настраиваем диск ==='",
      "qm set ${var.template_vmid} --scsi0 ${var.storage_vm}:vm-${var.template_vmid}-disk-0",
      "qm set ${var.template_vmid} --boot order=scsi0",
      "qm set ${var.template_vmid} --scsihw virtio-scsi-pci",
      "qm set ${var.template_vmid} --ide2 ${var.storage_vm}:cloudinit",
      "qm set ${var.template_vmid} --serial0 socket --vga serial0",
      "qm set ${var.template_vmid} --agent enabled=1"
    ]
  }
}

# 3. Конвертация в шаблон
resource "terraform_data" "convert_to_template" {
  depends_on = [terraform_data.download_and_import_image]

  triggers_replace = {
    vm_id = var.template_vmid
    timestamp = timestamp()
  }

  connection {
    type     = "ssh"
    user     = var.proxmox_ssh_username
    password = var.proxmox_ssh_password
    host     = regex("//([^:/]+)", var.pm_api_url)[0]
  }

  provisioner "remote-exec" {
    inline = [
      "echo '=== Проверяем что ВМ готова ==='",
      "qm status ${var.template_vmid}",
      "sleep 5",
      
      "echo '=== Конвертируем ВМ ${var.template_vmid} в шаблон ==='",
      "qm template ${var.template_vmid}"
    ]
  }
}

output "template_ready" {
  value = "Template ${var.template_vmid} создан."
  depends_on = [terraform_data.convert_to_template]
}
