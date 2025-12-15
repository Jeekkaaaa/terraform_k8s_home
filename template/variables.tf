variable "pm_api_url" {
  type = string
}

variable "pm_api_token_id" {
  type = string
}

variable "pm_api_token_secret" {
  type = string
}

variable "target_node" {
  type    = string
  default = "pve-k8s"
}

variable "template_vmid" {
  type    = number
  default = 9000
}

variable "ssh_public_key" {
  type = string
}

variable "storage" {
  type    = string
  default = "local-lvm"
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}
