# ВСЕ переменные которые есть в config.auto.tfvars

variable "pm_api_url" {}
variable "pm_api_token_id" {}
variable "pm_api_token_secret" {}
variable "proxmox_ssh_username" {}
variable "proxmox_ssh_password" {}

variable "target_node" {}
variable "template_vmid" {}
variable "ssh_public_key" {}

variable "network_config" {}
variable "cloud_init" {}
variable "static_ip_base" {}

variable "vm_specs" {}
variable "vmid_ranges" {}
variable "cluster_config" {}        # ДОБАВЬ ЭТУ
variable "template_specs" {}        # ДОБАВЬ ЭТУ
variable "storage_iso" {}           # ДОБАВЬ ЭТУ  
variable "storage_vm" {}            # ДОБАВЬ ЭТУ
