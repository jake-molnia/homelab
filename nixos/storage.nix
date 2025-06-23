# nixos/storage.nix - Dedicated storage configuration module
{ config, pkgs, lib, ... }:

{
  # Storage-specific system configurations
  
  # Create Kubernetes storage manifests
  environment.etc = {
    # NFS StorageClass
    "kubernetes/storage/nfs-storageclass.yaml".text = ''
      apiVersion: storage.k8s.io/v1
      kind: StorageClass
      metadata:
        name: nfs-shared
        annotations:
          storageclass.kubernetes.io/is-default-class: "false"
      provisioner: nfs.csi.k8s.io/nfs
      parameters:
        server: your-nas-ip  # Replace with your NFS server IP
        share: /path/to/shared
        mountPermissions: "0755"
      reclaimPolicy: Retain
      volumeBindingMode: Immediate
      ---
      apiVersion: storage.k8s.io/v1
      kind: StorageClass
      metadata:
        name: nfs-backups
        annotations:
          storageclass.kubernetes.io/is-default-class: "false"
      provisioner: nfs.csi.k8s.io/nfs
      parameters:
        server: your-nas-ip  # Replace with your NFS server IP
        share: /path/to/backups
        mountPermissions: "0755"
      reclaimPolicy: Retain
      volumeBindingMode: Immediate
    '';

    # Longhorn StorageClass (using raw 1TB Samsung NVMe)
    "kubernetes/storage/longhorn-storageclass.yaml".text = ''
      apiVersion: storage.k8s.io/v1
      kind: StorageClass
      metadata:
        name: longhorn-fast
        annotations:
          storageclass.kubernetes.io/is-default-class: "true"
      provisioner: driver.longhorn.io
      allowVolumeExpansion: true
      reclaimPolicy: Delete
      volumeBindingMode: Immediate
      parameters:
        numberOfReplicas: "1"  # Single node homelab setup
        staleReplicaTimeout: "2880"
        fromBackup: ""
        fsType: "ext4"
        dataLocality: "best-effort"
        # Longhorn will automatically detect and use /dev/nvme0n1
    '';

    # Longhorn backup configuration - COMMENTED OUT
    # "kubernetes/storage/longhorn-backup-target.yaml".text = ''
    #   apiVersion: v1
    #   kind: Secret
    #   metadata:
    #     name: longhorn-backup-target
    #     namespace: longhorn-system
    #   type: Opaque
    #   data:
    #     BACKUP_TARGET: bmZzOi8vL21udC9uZnMvYmFja3Vwcy9sb25naG9ybi1iYWNrdXBz  # base64: nfs:///mnt/nfs/backups/longhorn-backups
    # '';
  };

  # Storage monitoring and health check scripts
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "check-storage-health" ''
      #!/bin/bash
      echo "=== Storage Health Check ==="
      echo
      
      echo "NFS Mounts:"
      mount | grep nfs || echo "No NFS mounts found"
      echo
      
      echo "Samsung NVMe SSD (Longhorn):"
      if [ -b "/dev/nvme0n1" ]; then
        echo "NVMe found: /dev/nvme0n1"
        echo "Size: $(lsblk /dev/nvme0n1 | tail -1 | awk '{print $4}')"
        echo "Model: $(nvme id-ctrl /dev/nvme0n1 2>/dev/null | grep mn | awk '{print $3}' || echo 'Unknown')"
      else
        echo "ERROR: Samsung NVMe not found at /dev/nvme0n1"
      fi
      echo
      
      echo "Storage Usage:"
      df -h | grep -E "(nfs|nvme|/dev/)" || echo "No storage filesystems mounted"
      echo
      
      echo "Kubernetes Storage Classes:"
      if [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        kubectl get storageclass 2>/dev/null || echo "Cannot connect to Kubernetes API"
      else
        echo "k3s not configured"
      fi
    '')

    (writeShellScriptBin "apply-storage-classes" ''
      #!/bin/bash
      echo "Applying storage class configurations..."
      
      export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
      
      # Wait for k3s to be ready
      echo "Waiting for k3s API..."
      until kubectl get nodes; do
        sleep 5
      done
      
      echo "Applying NFS storage classes..."
      kubectl apply -f /etc/kubernetes/storage/nfs-storageclass.yaml
      
      echo "Checking Longhorn installation..."
      kubectl get pods -n longhorn-system
      
      # if kubectl get namespace longhorn-system; then
      #   echo "Applying Longhorn backup configuration..."
      #   kubectl apply -f /etc/kubernetes/storage/longhorn-backup-target.yaml
      # else
      #   echo "Longhorn not yet installed, skipping backup configuration"
      # fi
      
      echo "Storage classes applied successfully!"
    '')

    # (writeShellScriptBin "longhorn-backup" ''
    #   #!/bin/bash
    #   # Simple script to trigger Longhorn backups
    #   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    #   
    #   echo "Triggering Longhorn backups..."
    #   
    #   # List all PVCs and create snapshots
    #   kubectl get pvc --all-namespaces -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"' | while read pvc; do
    #     namespace=$(echo $pvc | cut -d'/' -f1)
    #     name=$(echo $pvc | cut -d'/' -f2)
    #     
    #     echo "Creating snapshot for PVC $pvc"
    #     
    #     # Create volume snapshot (this requires snapshot controller to be installed)
    #     cat <<EOF | kubectl apply -f -
    #   apiVersion: snapshot.storage.k8s.io/v1
    #   kind: VolumeSnapshot
    #   metadata:
    #     name: $name-backup-$(date +%Y%m%d-%H%M%S)
    #     namespace: $namespace
    #   spec:
    #     source:
    #       persistentVolumeClaimName: $name
    #     volumeSnapshotClassName: longhorn
    #   EOF
    #   done
    #   
    #   echo "Backup snapshots created!"
    # '')
  ];

  # Systemd services for storage management
  systemd.services = {
    "storage-health-monitor" = {
      description = "Storage health monitoring";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'check-storage-health > /var/log/storage-health.log 2>&1'";
        User = "root";
      };
    };

    "apply-storage-config" = {
      description = "Apply Kubernetes storage configurations";
      after = [ "k3s.service" "longhorn-deploy.service" ];
      wants = [ "k3s.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 120";  # Wait for Longhorn to be ready
        ExecStart = "${pkgs.bash}/bin/bash -c 'apply-storage-classes'";
        User = "root";
        Environment = "KUBECONFIG=/etc/rancher/k3s/k3s.yaml";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };

  # Systemd timers for automated tasks
  systemd.timers = {
    "storage-health-monitor" = {
      description = "Run storage health check every hour";
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
      wantedBy = [ "timers.target" ];
    };

    # "longhorn-backup" = {
    #   description = "Run Longhorn backups daily";
    #   timerConfig = {
    #     OnCalendar = "daily";
    #     Persistent = true;
    #     RandomizedDelaySec = "30m";
    #   };
    #   wantedBy = [ "timers.target" ];
    # };
  };

  # Log rotation for storage logs
  services.logrotate = {
    enable = true;
    settings = {
      "/var/log/storage-health.log" = {
        frequency = "weekly";
        rotate = 4;
        compress = true;
        missingok = true;
        notifempty = true;
      };
    };
  };

  # Ensure required directories exist  
  systemd.tmpfiles.rules = [
    "d /var/log/longhorn 0755 root root -"
    "d /etc/kubernetes 0755 root root -"
    "d /etc/kubernetes/storage 0755 root root -"
    # "d /mnt/nfs/backups/longhorn-backups 0755 root root -"  # Backup NFS commented out
    # Longhorn will use raw NVMe device, not file storage
  ];

  # Storage-specific kernel optimizations
  boot.kernel.sysctl = {
    # Optimize for storage I/O
    "vm.dirty_expire_centisecs" = 500;
    "vm.dirty_writeback_centisecs" = 100;
    "kernel.pid_max" = 4194304;  # More PIDs for container workloads
  };
}