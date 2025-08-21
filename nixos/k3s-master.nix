# nixos/k3s-master.nix - k3s master node configuration
{ config, pkgs, ... }:

{
  # Hostname and networking
  networking = {
    hostName = "k3s-master";
    interfaces.ens18 = {
      # Adjust interface name as needed
      ipv4.addresses = [{
        address = "10.10.10.37"; # Fixed to match flake.nix
        prefixLength = 24;
      }];
    };
  };

  # k3s master configuration
  services.k3s = {
    enable = true;
    role = "server";
    # Remove the token line - let k3s generate one automatically
    extraFlags = toString [
      "--cluster-init"
      "--write-kubeconfig-mode=644"
      "--tls-san=10.10.10.37" # Add this for proper certificate handling
      "--with-node-id" # Add unique node ID to avoid hostname conflicts
    ];
  };

  # Additional packages for master node
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
  ];

  # Additional firewall rules for k3s master
  networking.firewall.allowedTCPPorts = [
    6443 # k3s API server
    10250 # kubelet API
    2379 # etcd client
    2380 # etcd peer
  ];
}
