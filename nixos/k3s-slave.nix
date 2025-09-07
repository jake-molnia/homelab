{ config, pkgs, ... }:

{
  # Import environment variables
  imports = [ ./util/load-env.nix ];
  # Hostname and networking
  networking = {
    hostName = config.env.K3S_SLAVE_HOSTNAME;
    interfaces.ens18 = {
      ipv4.addresses = [{
        address = config.env.K3S_SLAVE_IP;
        prefixLength = 24;
      }];
    };
  };

  # Mount the NVMe drive at /data
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/${config.env.K3S_SLAVE_NVME_UUID}";
    fsType = "ext4";
  };

  # k3s agent configuration - this will join the master
  services.k3s = {
    enable = true;
    role = "agent";
    token = config.env.K3S_TOKEN;
    serverAddr = "https://${config.env.K3S_MASTER_IP}:6443";
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
