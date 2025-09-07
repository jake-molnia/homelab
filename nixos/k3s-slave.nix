{ config, pkgs, ... }:

let
  vars = import ./variables.nix;
in
{
  # K3s slave configuration
  # Hostname and networking
  networking = {
    hostName = vars.networking.slave.hostname;
    interfaces.ens18 = {
      ipv4.addresses = [{
        address = vars.networking.slave.ip;
        prefixLength = 24;
      }];
    };
  };

  # Mount the NVMe drive at /data
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/${vars.networking.slave.nvmeUuid}";
    fsType = "ext4";
  };

  # k3s agent configuration - this will join the master
  services.k3s = {
    enable = true;
    role = "agent";
    token = vars.k3s.token;
    serverAddr = "https://${vars.networking.master.ip}:6443";
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
