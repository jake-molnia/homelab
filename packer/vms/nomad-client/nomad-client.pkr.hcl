# Ubuntu Server Noble (24.04.x) running Nomad Client
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

variable "ceph_mon_host" {
    type = string
    default = "10.10.10.20:6789"
    description = "Ceph monitor host(s), comma separated if multiple"
}

variable "ceph_fs_name" {
    type = string
    default = "cephfs"
    description = "Name of the CephFS filesystem"
}

source "proxmox-iso" "nomad-client" {
    # Proxmox Connection Settings
    proxmox_url = "${var.proxmox_api_url}"
    username = "${var.proxmox_api_token_id}"
    token = "${var.proxmox_api_token_secret}"
    insecure_skip_tls_verify = true

    # VM General Settings
    node = "ms01a"
    vm_id = "903"
    vm_name = "nomad-client"
    template_description = "Ubuntu Server Noble running Nomad Client with CephFS mount"

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
        disk_size = "30G"
        format = "raw"
        storage_pool = "local-lvm"
        type = "virtio"
    }

    # VM CPU Settings
    cores = "6"

    # VM Memory Settings
    memory = "12288"

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

    boot = "c"
    boot_wait = "10s"
    communicator = "ssh"

    # PACKER Autoinstall Settings
    http_directory = "http"

    ssh_username = "nomad"
    ssh_private_key_file = "~/.ssh/keys/id_homelab-vms"
    ssh_timeout = "30m"
    ssh_pty = true
}

# Build Definition to create the VM Template
build {
    name = "nomad-client"
    sources = ["source.proxmox-iso.nomad-client"]

    # Provisioning the VM Template for Cloud-Init Integration
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

    # Cloud-Init Configuration
    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    # Copy Ceph keyring
    provisioner "file" {
        source = "files/ceph.client.admin.keyring"
        destination = "/tmp/ceph.client.admin.keyring"
    }

    provisioner "shell" {
        inline = [
            "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg",
            "sudo mkdir -p /etc/ceph",
            "sudo cp /tmp/ceph.client.admin.keyring /etc/ceph/",
            "sudo chmod 600 /etc/ceph/ceph.client.admin.keyring"
        ]
    }

    # Provision Nomad client with CephFS
    provisioner "file" {
      source = "./provision.sh"
      destination = "/tmp/provision.sh"
    }

    provisioner "shell" {
      inline = [
        "sudo chmod +x /tmp/provision.sh",
        "sudo /tmp/provision.sh '${var.ceph_mon_host}' '${var.ceph_fs_name}'",
        "sudo rm /tmp/provision.sh"
      ]
    }
}
