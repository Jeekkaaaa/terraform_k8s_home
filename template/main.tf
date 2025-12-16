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

# Загружаем облачный образ Ubuntu в Proxmox автоматически
resource "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = var.storage
  node_name    = var.target_node

  source_file {
    path = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  }
}

# Создаем шаблон из загруженного образа
resource "proxmox_vm_qemu" "ubuntu_template" {
  depends_on = [proxmox_virtual_environment_file.ubuntu_cloud_image]
  
  name        = "ubuntu-template"
  vmid        = var.template_vmid
  target_node = var.target_node
  description = "Ubuntu 22.04 Cloud-Init Template"
  
  # Создаем новую ВМ, не клонируем
  clone = null
  
  cpu {
    cores   = var.template_specs.cpu_cores
    sockets = var.template_specs.cpu_sockets
  }
  
  memory = var.template_specs.memory_mb
  
  # Основной диск (создаем из образа)
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
  
  # Сеть (без IP для шаблона)
  network {
    id     = 0
    model  = "virtio"
    bridge = var.bridge
  }
  
  # Cloud-init настройки
  ciuser       = var.cloud_init.user
  searchdomain = join(" ", var.cloud_init.search_domains)
  sshkeys      = var.ssh_public_key
  
  # Настройки загрузки
  boot      = "order=scsi0"
  bootdisk  = "scsi0"
  scsihw    = "virtio-scsi-pci"
  agent     = 1
  os_type   = "cloud-init"
  template  = true  # Создаем сразу как шаблон!
  
  lifecycle {
    ignore_changes = [
      disk[0].size,
      network,
    ]
  }
}

# Информационный вывод
output "template_ready" {
  value = "Template ${var.template_vmid} created from cloud image"
}
