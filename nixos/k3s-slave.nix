{ config, pkgs, ... }:

{
  # Hostname and networking
  networking = {
    hostName = "k3s-slave";
    interfaces.ens18 = {
      ipv4.addresses = [{
        address = "10.10.10.74";
        prefixLength = 24;
      }];
    };
  };

  # k3s agent configuration - this will join the master
  services.k3s = {
    enable = true;
    role = "agent";
    token = "K1044a39f6549970b39d8709589e11b925c89c43be2bac3ebdaf0cea0672c492f09::server:6a9350bf0df297f57a05881844198408";
    serverAddr = "https://10.10.10.134:6443";
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
