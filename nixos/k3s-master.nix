# nixos/k3s-master.nix - k3s master node configuration
{ config, pkgs, lib, ... }:

let
  # Automatically discover all YAML files in the kubernetes directory
  kubernetesDir = ../kubernetes;
  manifestFiles = builtins.readDir kubernetesDir;

  # Filter to only include .yaml and .yml files
  yamlFiles = lib.filterAttrs
    (name: type:
      type == "regular" &&
      (lib.hasSuffix ".yaml" name || lib.hasSuffix ".yml" name)
    )
    manifestFiles;

  # Generate systemd tmpfiles rules for each YAML file
  manifestRules = lib.mapAttrsToList
    (fileName: _:
      "C /var/lib/rancher/k3s/server/manifests/${fileName} 0644 root root - ${kubernetesDir}/${fileName}"
    )
    yamlFiles;

in
{
  # Hostname and networking
  networking = {
    hostName = "k3s-master";
    interfaces.ens18 = {
      # Adjust interface name as needed
      ipv4.addresses = [{
        address = "10.10.10.108"; # Fixed to match flake.nix
        prefixLength = 24;
      }];
    };
  };

  # k3s master configuration
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--cluster-init"
      "--write-kubeconfig-mode=644"
      "--tls-san=10.10.10.37"
      "--with-node-id"
    ];
  };

  # Automatically copy all YAML files from kubernetes/ directory
  systemd.tmpfiles.rules = [
    "d /var/lib/rancher/k3s/server/manifests 0755 root root -"
  ] ++ manifestRules;

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
