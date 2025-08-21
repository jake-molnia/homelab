# nixos/k3s-master.nix - Simple k3s master node configuration
{ config, pkgs, ... }:

{
  # Hostname and networking
  networking = {
    hostName = "k3s-slave";
    interfaces.ens18 = {
      # Adjust interface name as needed
      ipv4.addresses = [{
        address = "10.10.10.74";
        prefixLength = 24;
      }];
    };
  };

  # Simple k3s master configuration
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--cluster-init"
      "--write-kubeconfig-mode=644"
    ];
  };

  # Generate a token for the cluster
  environment.etc."rancher/k3s/token".text = "K10f8a7b2c9d4e5f6789abcdef123456::server:1234567890abcdef";

  # Additional packages for master node
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
  ];
}
