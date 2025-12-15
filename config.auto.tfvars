# config.auto.tfvars
# ВСЁ, что вы меняете для деплоя, указывается ТОЛЬКО здесь!

# ========== ПРОКСМОКС API ==========
# Эти значения передаются через секреты в CI/CD
# pm_api_url = "https://your-proxmox:8006/api2/json"
# pm_api_token_id = "user@pve!token"
# pm_api_token_secret = "uuid"

# ========== ОСНОВНЫЕ НАСТРОЙКИ ==========
target_node = "pve-k8s"
ssh_public_key_path = "/root/.ssh/id_ed25519.pub"
ssh_private_key_path = "/root/.ssh/id_ed25519"

# ========== КОНФИГ КЛАСТЕРА ==========
cluster_config = {
  masters_count = 1          # Начинаем с 1 для теста
  workers_count = 0
  cluster_name  = "home-k8s"
  domain        = "home.lab"
}

# ========== ДИАПАЗОНЫ VM ID ==========
vmid_ranges = {
  masters = {
    start = 2000
    end   = 2009
  }
  workers = {
    start = 2100
    end   = 2109
  }
}

# ========== ХАРАКТЕРИСТИКИ ВМ ==========
vm_specs = {
  master = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 2048
    disk_size_gb       = 20
    disk_storage       = "local-lvm"
    disk_format        = "raw"
    cloudinit_storage  = "local-lvm"  # КРИТИЧЕСКИ ВАЖНО!
  }
  worker = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 2048
    disk_size_gb       = 20
    disk_storage       = "local-lvm"
    disk_format        = "raw"
    cloudinit_storage  = "local-lvm"  # КРИТИЧЕСКИ ВАЖНО!
  }
}

# ========== СЕТЕВЫЕ НАСТРОЙКИ ==========
network_config = {
  subnet       = "192.168.0.0/24"
  gateway      = "192.168.0.1"
  dns_servers  = ["8.8.8.8", "1.1.1.1"]
  bridge       = "vmbr0"
}

# ========== CLOUD-INIT ==========
cloud_init = {
  user           = "ubuntu"
  search_domains = ["home.lab"]
}

# ========== НАСТРОЙКИ IP ==========
auto_static_ips = true
static_ip_base  = 110
