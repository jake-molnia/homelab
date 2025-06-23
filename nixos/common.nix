# nixos/common.nix - Configuration shared by both k3s nodes
{ config, pkgs, ... }:

{
  # Basic system configuration
  system.stateVersion = "25.05";
  
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Timezone
  time.timeZone = "America/New_York";

  # Bootloader configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";  # Adjust as needed

  # Kernel modules for storage
  boot.kernelModules = [ 
    "nfs" 
    "nfsd" 
    "iscsi_tcp" 
    "nvme" 
    "dm-snapshot" 
    "dm-mirror" 
    "dm-thin-pool" 
  ];

  # SSH configuration (transitional - allows both keys and passwords for now)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";              # Allow root login
      PasswordAuthentication = true;        # Keep password auth during transition
      PermitEmptyPasswords = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBD/qDANIh2fQzUGgODMfrJLKzR4qPgqME5gyaz0Z1JSODU6Fw+m3umLrBkNBR5BokZJ6O9ZHhV8R86UEsspbD9Q= Public key for PIV Authentication"
  ];

  # Packages available on all nodes (now with storage support)
  environment.systemPackages = with pkgs; [
    cowsay
    htop
    curl
    wget
    git
    vim
    spice-vdagent
    # Storage packages
    nfs-utils
    openiscsi
    lvm2
    parted
    smartmontools
    util-linux
    cryptsetup
    # Kubernetes storage tools
    kubectl
    kubernetes-helm
  ];

  # Services for storage support
  services = {
    # NFS client support
    rpcbind.enable = true;
    
    # iSCSI initiator for Longhorn
    openiscsi = {
      enable = true;
      name = "iqn.2020-04.com.homelab:${config.networking.hostName}";
    };
  };

  # Network configuration common to both nodes
  networking = {
    useDHCP = false;
    defaultGateway = "10.10.10.1";  # Adjust to your network
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
  };

  # Firewall rules for k3s and storage
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      6443  # k3s API server
      10250 # kubelet
      # Longhorn ports
      8000  # Longhorn UI
      9500  # Longhorn manager
      9501  # Longhorn manager
      9502  # Longhorn manager 
      9503  # Longhorn manager
      # iSCSI
      3260  # iSCSI target
    ];
    allowedUDPPorts = [
      8472  # flannel VXLAN
      111   # NFS rpcbind
      2049  # NFS
    ];
  };

  # Docker for k3s
  virtualisation.docker.enable = true;

  # System directories for storage
  systemd.tmpfiles.rules = [
    "d /mnt/nfs 0755 root root -"
    "d /mnt/nfs/shared 0755 root root -"
    "d /mnt/nfs/backups 0755 root root -"
    "d /var/lib/longhorn 0755 root root -"
  ];
}