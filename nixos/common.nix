# nixos/common.nix - Simplified configuration shared by k3s nodes
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
  boot.loader.grub.device = "/dev/sda";

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
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBD/qDANIh2fQzUGgODMfrJLKzR4qPgqME5gyaz0Z1JSODU6Fw+m3umLrBkNBR5BokZJ6O9ZHhV8R86UEsspbD9Q= Public key for PIV Authentication"
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
  ];

  # Network configuration
  networking = {
    useDHCP = false;
    defaultGateway = "10.10.10.1";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
  };

  # Firewall rules for k3s
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      6443  # k3s API server
      10250 # kubelet
    ];
    allowedUDPPorts = [
      8472  # flannel VXLAN
    ];
  };

  # Docker for k3s
  virtualisation.docker.enable = true;
}