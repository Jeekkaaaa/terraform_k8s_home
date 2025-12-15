# Корневой модуль для оркестрации развертывания

terraform {
  required_version = ">= 1.0"
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

# Модуль создания шаблона
module "template" {
  source = "./template"
  
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  target_node         = var.target_node
  ssh_public_key      = file(var.ssh_public_key_path)
}

# Модуль мастер-нод
module "master" {
  source = "./master"
  depends_on = [module.template]
  
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  
  target_node         = var.target_node
  ssh_public_key_path = var.ssh_public_key_path
  
  cluster_config      = var.cluster_config
  vmid_ranges         = var.vmid_ranges
  vm_specs            = var.vm_specs
  network_config      = var.network_config
  cloud_init          = var.cloud_init
  auto_static_ips     = var.auto_static_ips
  static_ip_base      = var.static_ip_base
}

# Модуль воркер-нод (пока отключен - workers_count = 0)
# module "worker" {
#   source = "./worker"
#   depends_on = [module.template]
#   
#   pm_api_url          = var.pm_api_url
#   pm_api_token_id     = var.pm_api_token_id
#   pm_api_token_secret = var.pm_api_token_secret
#   
#   target_node         = var.target_node
#   ssh_public_key_path = var.ssh_public_key_path
#   
#   cluster_config      = var.cluster_config
#   vmid_ranges         = var.vmid_ranges
#   vm_specs            = var.vm_specs
#   network_config      = var.network_config
#   cloud_init          = var.cloud_init
#   auto_static_ips     = var.auto_static_ips
#   static_ip_base      = var.static_ip_base
# }

output "template_info" {
  value = module.template.template_id
}

output "masters_info" {
  value = module.master.masters
}
