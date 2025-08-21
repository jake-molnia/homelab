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
    token = "K1045f87291b4b664f8ad2e69e57a3106d724c04443b2d33b3202f56b58695ebd7c::server:1234567890abcdef";
    serverAddr = "https://10.10.10.37:6443";
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
