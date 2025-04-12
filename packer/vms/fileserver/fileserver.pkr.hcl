# Ubuntu Server Noble (24.04.x) File Server with Ceph
# Based on Pi-hole template by Jacob Molnia
# ---
packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# Variable Definitions
variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

# Ceph Variables
variable "ceph_mon_host" {
    type = string
    default = "10.10.10.40:6789"
    description = "Ceph monitor host(s), comma separated if multiple"
}

variable "ceph_fs_name" {
    type = string
    default = "cephfs"
    description = "Name of the CephFS filesystem to mount"
}

variable "ceph_user" {
    type = string
    default = "client.admin"
    description = "Ceph user for authentication"
}

source "proxmox-iso" "fileserver" {

    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    # (Optional) Skip TLS Verification
    insecure_skip_tls_verify = true

    # VM General Settings
    node = "ms01a"
    vm_id = "905"
    vm_name = "fileserver"
    template_description = "Ubuntu Server Noble running Samba/NFS with Ceph storage"

    boot_iso {
      type = "scsi"
      iso_file = "local:iso/ubuntu-24.04.2-live-server-amd64.iso"
      unmount = true
    }

    # VM System Settings
    qemu_agent = true

    # VM Hard Disk Settings
    scsi_controller = "virtio-scsi-pci"

    disks {
        disk_size = "20G"
        format = "raw"
        storage_pool = "local-lvm"
        type = "virtio"
    }

    # VM CPU Settings
    cores = "2"

    # VM Memory Settings
    memory = "4096"

    # VM Network Settings
    network_adapters {
        model = "virtio"
        bridge = "vmbr0"
        firewall = "false"
    }

    # VM Cloud-Init Settings
    cloud_init = true
    cloud_init_storage_pool = "local-lvm"

    # PACKER Boot Commands
    boot_command = [
        "<esc><wait>",
        "e<wait>",
        "<down><down><down><end>",
        "<bs><bs><bs><bs><wait>",
        "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
        "<f10><wait>"
    ]

    boot                    = "c"
    boot_wait               = "10s"
    communicator            = "ssh"

    # PACKER Autoinstall Settings
    http_directory          = "http"

    ssh_username            = "fileadmin"
    ssh_private_key_file    = "~/.ssh/keys/id_homelab-vms"

    # Raise the timeout, when installation takes longer
    ssh_timeout             = "30m"
    ssh_pty                 = true
}

# Build Definition to create the VM Template
build {

    name = "fileserver"
    sources = ["source.proxmox-iso.fileserver"]

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo rm -f /etc/netplan/00-installer-config.yaml",
            "sudo sync"
        ]
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    # Copy Ceph keyring
    provisioner "file" {
        source = "files/ceph.client.admin.keyring"
        destination = "/tmp/ceph.client.admin.keyring"
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
    provisioner "shell" {
        inline = [
            "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg",
            "sudo mkdir -p /etc/ceph",
            "sudo cp /tmp/ceph.client.admin.keyring /etc/ceph/",
            "sudo chmod 600 /etc/ceph/ceph.client.admin.keyring"
        ]
    }

    provisioner "file" {
      source = "./provision.sh"
      destination = "/tmp/provision.sh"
    }

    provisioner "shell" {
      inline = [
        "sudo chmod +x /tmp/provision.sh",
        "sudo /tmp/provision.sh '${var.ceph_mon_host}' '${var.ceph_fs_name}' '${var.ceph_user}'",
        "sudo rm /tmp/provision.sh"
      ]
    }
}
