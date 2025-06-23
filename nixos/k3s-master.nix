# nixos/k3s-master.nix - k3s master node configuration
{ config, pkgs, ... }:

{
  # Hostname and networking specific to master
  networking = {
    hostName = "k3s-master";
    interfaces.ens18 = {  # Adjust interface name as needed
      ipv4.addresses = [{
        address = "10.10.10.110";
        prefixLength = 24;
      }];
    };
  };

  # k3s master configuration
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--cluster-init"  # Initialize a new cluster
      "--disable=traefik"  # Disable traefik if you want to use your own ingress
      "--write-kubeconfig-mode=644"
      "--kube-controller-manager-arg=bind-address=0.0.0.0"
      "--kube-proxy-arg=metrics-bind-address=0.0.0.0"
      "--kube-scheduler-arg=bind-address=0.0.0.0"
    ];
  };

  # Additional firewall rules for master
  networking.firewall.allowedTCPPorts = [
    6443   # k3s API server
    2379   # etcd client
    2380   # etcd peer
  ];

  # Create k3s token file for slave nodes to join
  # You'll need to set this token and share it with slave nodes
  environment.etc."rancher/k3s/token".text = "your-secure-token-here";

  # Additional packages for master node
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
  ];

  # Ensure k3s starts after network is ready
  systemd.services.k3s.after = [ "network-online.target" ];
  systemd.services.k3s.wants = [ "network-online.target" ];
}