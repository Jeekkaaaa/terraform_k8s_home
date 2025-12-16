output "template_id" {
  value = proxmox_vm_qemu.ubuntu_template.vmid
}

output "template_name" {
  value = proxmox_vm_qemu.ubuntu_template.name
}

output "template_ready" {
  value = true
}
