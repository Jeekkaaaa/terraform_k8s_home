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
}

# Скачиваем образ через external data (работает без провайдера http)
data "external" "download_image" {
  program = ["bash", "-c", <<-EOT
    set -e
    TEMP_FILE="/tmp/jammy-server-cloudimg-amd64.img"
    
    # Пробуем скачать 3 раза
    for i in {1..3}; do
      echo "Попытка $i скачивания образа..." >&2
      if curl -L -s -f -o "$TEMP_FILE" \
        "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"; then
        echo "{\"downloaded\": \"true\", \"path\": \"$TEMP_FILE\"}"
        exit 0
      fi
      sleep 10
    done
    
    echo "{\"downloaded\": \"false\", \"path\": \"\"}"
    exit 1
  EOT
  ]
}

# Загружаем файл в Proxmox
resource "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = var.storage_iso
  node_name    = var.target_node
  overwrite    = true
  
  source_file {
    path = data.external.download_image.result.path
  }
}

# Остальная конфигурация шаблона без изменений...
