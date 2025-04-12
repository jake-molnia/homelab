#!/bin/bash
set -e

# Get parameters from Packer
CEPH_MON_HOST="$1"
CEPH_FS_NAME="$2"
CEPH_USER="$3"

# Default values if not provided
CEPH_MON_HOST=${CEPH_MON_HOST:-"10.10.10.20:6789"}
CEPH_FS_NAME=${CEPH_FS_NAME:-"cephfs"}
CEPH_USER=${CEPH_USER:-"client.admin"}

echo "Setting up File Server with CephFS storage"
echo "Ceph Monitor: $CEPH_MON_HOST"
echo "CephFS Filesystem: $CEPH_FS_NAME"
echo "Ceph User: $CEPH_USER"

# Update system
apt update && apt upgrade -y

# Install dependencies
apt install -y curl sudo ceph-common nfs-kernel-server samba

# Create directories
mkdir -p /etc/ceph
mkdir -p /mnt/cephfs
mkdir -p /export/shares

# Configure Ceph
cat > /etc/ceph/ceph.conf << EOF
[global]
mon host = ${CEPH_MON_HOST}
EOF

# Keyring is already copied by Packer

# Create mount script
cat > /usr/local/bin/mount-cephfs.sh << EOF
#!/bin/bash

# Check if CephFS is already mounted
if ! mount | grep -q "/mnt/cephfs"; then
    # Mount the CephFS filesystem
    echo "Mounting CephFS..."
    mount -t ceph ${CEPH_MON_HOST}:/ /mnt/cephfs \
        -o name=${CEPH_USER//client./},fs=${CEPH_FS_NAME},_netdev

    # Create export directories if they don't exist
    mkdir -p /mnt/cephfs/nfs
    mkdir -p /mnt/cephfs/samba

    # Set appropriate permissions
    chmod 777 /mnt/cephfs/samba
    chmod 777 /mnt/cephfs/nfs

    # Create symlink for NFS export
    ln -sfn /mnt/cephfs/nfs /export/shares
fi
EOF

chmod +x /usr/local/bin/mount-cephfs.sh

# Configure NFS exports
cat > /etc/exports << EOF
/export/shares *(rw,sync,no_subtree_check,no_root_squash)
EOF

# Configure Samba
cat > /etc/samba/smb.conf << EOF
[global]
   workgroup = WORKGROUP
   server string = Ceph File Server
   security = user
   map to guest = Bad User
   log file = /var/log/samba/%m.log
   max log size = 50
   dns proxy = no

[cephshare]
   path = /mnt/cephfs/samba
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0777
   directory mask = 0777
EOF

# Add systemd service to mount CephFS at boot
cat > /etc/systemd/system/cephfs-mount.service << EOF
[Unit]
Description=Mount CephFS
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mount-cephfs.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Set up auto-mounting on boot
systemctl daemon-reload
systemctl enable cephfs-mount.service
systemctl enable nfs-kernel-server
systemctl enable smbd

# Create an example readme file for the share
mkdir -p /tmp/initshare
cat > /tmp/initshare/README.txt << EOF
This is the shared CephFS storage.
Files placed here are stored on the Ceph cluster and are accessible from all VMs.
EOF

cat > /tmp/initshare/setup-client.sh << EOF
#!/bin/bash
# Run this on client machines to mount the NFS share

# Install NFS client
apt update && apt install -y nfs-common

# Create mount point
mkdir -p /mnt/cephshare

# Add to fstab
echo "fileserver:/export/shares /mnt/cephshare nfs defaults,_netdev 0 0" >> /etc/fstab

# Mount now
mount /mnt/cephshare
EOF

chmod +x /tmp/initshare/setup-client.sh

echo "File server setup complete!"
echo "The CephFS mount service will start automatically on boot."
echo "Your VMs can access the share via:"
echo "   - NFS: fileserver:/export/shares"
echo "   - SMB: \\\\fileserver\\cephshare"

# Reminder about how to directly mount CephFS on clients if needed
cat << EOF

# Direct CephFS Mount Instructions (Alternative)
If you prefer to directly mount CephFS on some clients instead of using NFS/SMB:

1. Install ceph-common package
2. Copy the Ceph keyring to the client
3. Mount with:
   mount -t ceph ${CEPH_MON_HOST}:/ /mnt/cephfs -o name=${CEPH_USER//client./},fs=${CEPH_FS_NAME}

EOF
