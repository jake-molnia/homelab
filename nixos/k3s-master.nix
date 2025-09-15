# nixos/k3s-master.nix - k3s master node configuration
{ config, pkgs, lib, ... }:

let
  vars = import ./variables.nix;
in
{
  # Hostname and networking configuration
  # Hostname and networking
  networking = {
    hostName = vars.networking.master.hostname;
    interfaces.ens18 = {
      # Adjust interface name as needed
      ipv4.addresses = [{
        address = vars.networking.master.ip;
        prefixLength = 24;
      }];
    };
  };

  # Mount the NVMe drive at /data
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/${vars.networking.master.nvmeUuid}";
    fsType = "ext4";
  };


  # k3s master configuration
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--cluster-init"
      "--write-kubeconfig-mode=644"
      "--tls-san=10.10.10.50"
      "--with-node-id"
    ];
  };

  # Additional packages for master node
  environment.systemPackages = with pkgs; [
  ];

  # Additional firewall rules for k3s master
  networking.firewall.allowedTCPPorts = [
    6443 # k3s API server
    10250 # kubelet API
    2379 # etcd client
    2380 # etcd peer
  ];
}
