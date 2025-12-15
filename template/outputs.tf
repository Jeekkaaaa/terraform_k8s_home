output "template_id" {
  value = proxmox_vm_qemu.ubuntu_template.vmid
}

output "template_name" {
  value = "ubuntu-template"
}

output "template_ready" {
  value = true
  description = "Template is ready for cloning"
}
