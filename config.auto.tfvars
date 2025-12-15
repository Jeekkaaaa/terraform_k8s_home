# config.auto.tfvars
# ВСЕ настройки здесь

target_node = "pve-k8s"
ssh_public_key_path = "/root/.ssh/id_ed25519.pub"
ssh_private_key_path = "/root/.ssh/id_ed25519"

cluster_config = {
  masters_count = 1
  workers_count = 0
  cluster_name  = "auto-k8s"
  domain        = "home.lab"
}

vmid_ranges = {
  masters = { start = 2000, end = 2009 }
  workers = { start = 2100, end = 2109 }
}

vm_specs = {
  master = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 2048
    disk_size_gb       = 20
    disk_storage       = "local-lvm"
    disk_format        = "raw"           # ← ДОБАВЛЕНО
    cloudinit_storage  = "local-lvm"     # ← ДОБАВЛЕНО
  }
  worker = {
    cpu_cores          = 2
    cpu_sockets        = 1
    memory_mb          = 2048
    disk_size_gb       = 20
    disk_storage       = "local-lvm"
    disk_format        = "raw"           # ← ДОБАВЛЕНО
    cloudinit_storage  = "local-lvm"     # ← ДОБАВЛЕНО
  }
}

network_config = {
  subnet       = "192.168.0.0/24"
  gateway      = "192.168.0.1"
  dns_servers  = ["8.8.8.8", "1.1.1.1"]
  bridge       = "vmbr0"
}

cloud_init = {
  user           = "ubuntu"
  search_domains = ["home.lab"]
}

auto_static_ips = true
static_ip_base  = 110
template_vmid   = 9000

# Настройки шаблона
storage = "local-lvm"
bridge = "vmbr0"
