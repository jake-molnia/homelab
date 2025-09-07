# nixos/common.nix - Simplified configuration shared by k3s nodes

{ config, pkgs, ... }:

{
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

  # SSH configuration
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PermitEmptyPasswords = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    config.env.SSH_AUTHORIZED_KEY
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
  ];

  # Import environment variables
  imports = [ ./load-env.nix ];

  # Network configuration
  networking = {
    useDHCP = false;
    defaultGateway = config.env.NETWORK_GATEWAY;
    nameservers = builtins.fromJSON config.env.DNS_SERVERS;
  };

  # Firewall rules for k3s
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
      6443 # k3s API server
      10250 # kubelet
    ];
    allowedUDPPorts = [
      8472 # flannel VXLAN
    ];
  };

  # Docker for k3s
  virtualisation.docker.enable = true;
}
