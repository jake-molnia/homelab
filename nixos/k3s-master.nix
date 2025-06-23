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

  # k3s master configuration with storage support
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--cluster-init"  # Initialize a new cluster
      "--disable=traefik"  # Disable traefik if you want to use your own ingress
      "--disable=local-storage"  # Disable local storage, we'll use Longhorn
      "--write-kubeconfig-mode=644"
      "--kube-controller-manager-arg=bind-address=0.0.0.0"
      "--kube-proxy-arg=metrics-bind-address=0.0.0.0"
      "--kube-scheduler-arg=bind-address=0.0.0.0"
      # Storage-specific flags
      "--kubelet-arg=feature-gates=KubeletInUserNamespace=false"
    ];
  };

  # Generate a proper random token (you should replace this with your own)
  environment.etc."rancher/k3s/token".text = "K10f8a7b2c9d4e5f6789abcdef123456::server:1234567890abcdef";

  # NFS mounts for media storage
  fileSystems = {
    "/mnt/nfs/media" = {
      device = "10.10.10.179:/mnt/data/media";  # Replace with your NFS server details
      fsType = "nfs";
      options = [ 
        "nfsvers=4.1" 
        "rsize=1048576" 
        "wsize=1048576" 
        "hard" 
        "intr" 
        "timeo=600" 
        "_netdev"
        "noauto"  # Don't auto-mount at boot, we'll handle this with systemd
      ];
    };
    
    #"/mnt/nfs/backups" = {
    #  device = "10.10.10.179:/path/to/backups";  # Replace with your NFS server details
    #  fsType = "nfs";
    #  options = [ 
    #    "nfsvers=4.1" 
    #    "rsize=1048576" 
    #    "wsize=1048576" 
    #    "hard" 
    #    "intr" 
    #    "timeo=600" 
    #    "_netdev"
    #    "noauto"
    #  ];
    #};
  };

  # Systemd services for reliable NFS mounting
  systemd.services = {
    "mount-nfs-media" = {
      description = "Mount NFS media storage";
      after = [ "network-online.target" "rpcbind.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.util-linux}/bin/mount /mnt/nfs/media";
        ExecStop = "${pkgs.util-linux}/bin/umount /mnt/nfs/media";
        TimeoutSec = 30;
        Restart = "on-failure";
        RestartSec = 10;
      };
    };

    #"mount-nfs-backups" = {
    #  description = "Mount NFS backup storage";
    #  after = [ "network-online.target" "rpcbind.service" ];
    #  wants = [ "network-online.target" ];
    #  wantedBy = [ "multi-user.target" ];
    #  serviceConfig = {
    #    Type = "oneshot";
    #    RemainAfterExit = true;
    #    ExecStart = "${pkgs.util-linux}/bin/mount /mnt/nfs/backups";
    #    ExecStop = "${pkgs.util-linux}/bin/umount /mnt/nfs/backups";
    #    TimeoutSec = 30;
    #    Restart = "on-failure";
    #    RestartSec = 10;
    #  };
    #};

    # Longhorn deployment service (runs after k3s is ready)
    "longhorn-deploy" = {
      description = "Deploy Longhorn storage system";
      after = [ "k3s.service" ];
      wants = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 60";  # Wait for k3s to be ready
        ExecStart = pkgs.writeShellScript "deploy-longhorn" ''
          # Wait for k3s to be ready
          until ${pkgs.kubectl}/bin/kubectl get nodes; do
            echo "Waiting for k3s to be ready..."
            sleep 10
          done
          
          # Apply Longhorn deployment
          ${pkgs.kubectl}/bin/kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml
          
          # Wait for Longhorn to be ready
          ${pkgs.kubectl}/bin/kubectl -n longhorn-system wait --for=condition=ready pod --all --timeout=600s
        '';
        User = "root";
        Environment = "KUBECONFIG=/etc/rancher/k3s/k3s.yaml";
      };
    };
  };

  # Additional firewall rules for master
  networking.firewall.allowedTCPPorts = [
    6443   # k3s API server
    2379   # etcd client
    2380   # etcd peer
  ];

  # Additional packages for master node
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes-helm
    # Storage monitoring tools
    iotop
    ncdu
    tree
  ];

  # Ensure k3s starts after network and storage is ready
  systemd.services.k3s = {
    #after = [ "network-online.target" "mount-nfs-media.service" "mount-nfs-backups.service" ];
    after = [ "network-online.target" "mount-nfs-media.service"];
    wants = [ "network-online.target" ];
  };

  # Node labels for storage
  environment.etc."rancher/k3s/node-labels".text = ''
    node.longhorn.io/create-default-disk=true
    storage.homelab/nfs-client=true
    storage.homelab/longhorn-node=true
  '';
}