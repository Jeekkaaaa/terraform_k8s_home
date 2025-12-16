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

# Создаем шаблон из облачного образа
resource "proxmox_vm_qemu" "ubuntu_template" {
  name        = "ubuntu-template"
  vmid        = var.template_vmid
  target_node = var.target_node
  desc        = "Ubuntu 22.04 Cloud-Init Template"
  
  # Не клонируем, создаем с нуля
  clone = null
  
  cpu {
    cores   = var.template_specs.cpu_cores
    sockets = var.template_specs.cpu_sockets
  }
  
  memory = var.template_specs.memory_mb
  
  # Основной диск
  disk {
    slot     = 0
    type     = "scsi"
    storage  = var.storage
    size     = "${var.template_specs.disk_size_gb}G"
    iothread = var.template_specs.disk_iothread
  }
  
  # Cloud-init диск
  disk {
    slot    = 2
    type    = "cloudinit"
    storage = var.storage
  }
  
  # Сеть (для шаблона можно без IP)
  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }
  
  # Cloud-init (без IP для шаблона)
  ciuser       = var.cloud_init.user
  searchdomain = join(" ", var.cloud_init.search_domains)
  sshkeys      = var.ssh_public_key
  
  # Критично для загрузки:
  boot      = "order=scsi0"
  bootdisk  = "scsi0"
  scsihw    = "virtio-scsi-pci"
  agent     = 1
  os_type   = "cloud-init"
  qemu_os   = "l26"  # Linux 2.6/3.x kernel
  
  # Источник - облачный образ (должен быть заранее загружен)
  # В Proxmox UI: local:iso/jammy-server-cloudimg-amd64.img
  
  lifecycle {
    ignore_changes = [
      disk[0].size,
      network,
    ]
  }
}

# После создания - конвертируем в шаблон
resource "null_resource" "convert_to_template" {
  depends_on = [proxmox_vm_qemu.ubuntu_template]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for VM ${var.template_vmid}..."
      sleep 30
      # Проверяем что ВМ создана
      if qm status ${var.template_vmid} >/dev/null 2>&1; then
        echo "Converting VM ${var.template_vmid} to template..."
        qm set ${var.template_vmid} --template 1
        echo "Template ${var.template_vmid} ready!"
      else
        echo "ERROR: VM ${var.template_vmid} not found!"
        exit 1
      fi
    EOT
  }
}
