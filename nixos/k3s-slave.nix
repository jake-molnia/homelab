{ config, pkgs, ... }:

{
  # Hostname and networking
  networking = {
    hostName = "k3s-slave";
    interfaces.ens18 = {
      ipv4.addresses = [{
        address = "10.10.10.51"; # Static IP for k3s-slave
        prefixLength = 24;
      }];
    };
  };

  # Mount the NVMe drive at /data
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/90ec5d0f-85e7-4f2d-9f0a-0b019abc4793";
    fsType = "ext4";
  };

  # k3s agent configuration - this will join the master
  services.k3s = {
    enable = true;
    role = "agent";
    token = "K1044a39f6549970b39d8709589e11b925c89c43be2bac3ebdaf0cea0672c492f09::server:6a9350bf0df297f57a05881844198408";
    serverAddr = "https://10.10.10.50:6443";
    extraFlags = toString [
      "--with-node-id" # Add unique node ID to avoid hostname conflicts
    ];
  };

  # Basic packages for worker node
  environment.systemPackages = with pkgs; [
    kubectl
  ];

  # Additional firewall rules for k3s agent
  networking.firewall.allowedTCPPorts = [
    10250 # kubelet API
  ];
}
