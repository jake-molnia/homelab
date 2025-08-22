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
    token = "K108bdf8558eeb607a5c630e244efe3fa49e1fc0af4669c4abb83125a9e21ae6227::server:24cfd6ef0a9ced2ab8773f665d2bdb66";
    serverAddr = "https://10.10.10.108:6443";
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
