# nixos/common.nix - Simplified configuration shared by k3s nodes

{ config, pkgs, lib, modulesPath, ... }:

let
  vars = import ./variables.nix;
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # System platform
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # No swap devices
  swapDevices = [ ];

  # Optimize Nix builds for all cores and large download buffer
  nix.settings.max-jobs = "auto";
  nix.settings.cores = 0;
  nix.settings.download-buffer-size = 268435456;
  # Basic system configuration
  system.stateVersion = "25.05";

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Timezone
  time.timeZone = "America/New_York";

  # Bootloader configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  services.qemuGuest.enable = true;

  boot.kernelParams = [
    "nvme_core.default_ps_max_latency_us=0" # Disable power saving
    "pcie_aspm=off" # Disable PCIe power management
  ];

  # Kernel modules configuration
  boot.initrd.availableKernelModules = [
    "ata_piix"
    "uhci_hcd"
    "virtio_pci"
    "virtio_scsi"
    "sd_mod"
    "sr_mod"
    "nvme"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-intel"
    "virtio_balloon"
    "iscsi_tcp" # iSCSI support for Longhorn
    "dm-snapshot" # Device mapper for snapshots
    "dm-thin-pool" # Thin provisioning
  ];
  boot.extraModulePackages = [ ];

  services = {
    openiscsi = {
      enable = true;
      name = "longhorn-${config.networking.hostName}";
    };
    # SSH configuration
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = false;
        PermitEmptyPasswords = false;
      };
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    vars.ssh.authorizedKey
  ];

  # Basic packages
  environment.systemPackages = with pkgs; [
    cowsay
    htop
    curl
    wget
    git
    vim
    spice-vdagent
    kubectl
    pciutils
    nvme-cli
    openiscsi # Required for Longhorn storage
    util-linux # For filesystem tools
    e2fsprogs # For ext4 tools
  ];

  # Network configuration
  networking = {
    useDHCP = false;
    defaultGateway = vars.networking.gateway;
    nameservers = vars.networking.dns;
  };

  # Firewall rules for k3s
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
      6443 # k3s API server
      10250 # kubelet
      9500
      9501
      9502
      9503
      9504 # Longhorn communication ports
    ];
    allowedUDPPorts = [
      8472 # flannel VXLAN
    ];
  };

  # Docker for k3s
  virtualisation.docker.enable = true;

  systemd.tmpfiles.rules = [
    "d /data/longhorn 0755 root root -"
  ];

  # Ensure both iSCSI services start automatically
  systemd.services.iscsid.enable = true;
  systemd.services.iscsi.enable = true;
  systemd.services.iscsid.wantedBy = [ "multi-user.target" ];
  systemd.services.iscsi.wantedBy = [ "multi-user.target" ];

  # Create symlinks for Longhorn to find iSCSI tools in expected locations
  system.activationScripts.longhorn-iscsi-symlinks = ''
    mkdir -p /usr/bin /sbin /bin
    ln -sf /run/current-system/sw/bin/iscsiadm /usr/bin/iscsiadm
    ln -sf /run/current-system/sw/bin/iscsiadm /sbin/iscsiadm
    ln -sf /run/current-system/sw/bin/iscsiadm /bin/iscsiadm
    ln -sf /run/current-system/sw/bin/nsenter /usr/bin/nsenter
  '';
}
