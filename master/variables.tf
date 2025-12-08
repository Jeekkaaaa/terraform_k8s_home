# variables.tf - Вариант с API токеном
variable "pm_api_url" {
  description = "URL API Proxmox (например, https://192.168.0.222:8006/api2/json)"
  type        = string
  sensitive   = true
}

variable "pm_api_token_id" {
  description = "Proxmox API Token ID (формат 'user!token-name', например 'root@pam!terraform')"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "target_node" {
  description = "Имя хоста Proxmox, на котором создавать ВМ (например, 'pve')"
  type        = string
  default     = "pve"
}

variable "ssh_public_key_path" {
  description = "Путь к файлу с публичным SSH-ключом"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Путь к файлу с приватным SSH-ключом (для подключения к ВМ)"
  type        = string
  default     = "~/.ssh/id_rsa"
}
