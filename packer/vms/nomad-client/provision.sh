#!/bin/bash
set -e

# Get parameters from Packer
CEPH_MON_HOST="$1"
CEPH_FS_NAME="$2"

# Default values if not provided
CEPH_MON_HOST=${CEPH_MON_HOST:-"10.10.10.20:6789"}
CEPH_FS_NAME=${CEPH_FS_NAME:-"cephfs"}

echo "Setting up Nomad client with CephFS storage"
echo "Ceph Monitor: $CEPH_MON_HOST"
echo "CephFS Filesystem: $CEPH_FS_NAME"

# Update System with non-interactive frontend to avoid prompts
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install Dependencies
apt install -y curl wget gpg coreutils sudo unzip jq dnsutils net-tools ceph-common

# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
| tee /etc/apt/sources.list.d/hashicorp.list

# Update and install Nomad and Consul with non-interactive settings
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" nomad consul

# Create necessary directories
mkdir -p /opt/nomad/data
mkdir -p /opt/nomad/plugins
mkdir -p /opt/consul/data
mkdir -p /etc/nomad.d
mkdir -p /etc/consul.d

# Set proper permissions
chmod 700 /opt/nomad/data
chmod 700 /opt/consul/data

# Install CNI plugins for Nomad
export ARCH_CNI=$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)
export CNI_PLUGIN_VERSION=v1.6.2
curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/cni-plugins-linux-${ARCH_CNI}-${CNI_PLUGIN_VERSION}.tgz"
mkdir -p /opt/cni/bin
tar -C /opt/cni/bin -xzf cni-plugins.tgz
rm cni-plugins.tgz

# Install Docker for Nomad
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create Ceph configuration
mkdir -p /etc/ceph
cat > /etc/ceph/ceph.conf << EOF
[global]
mon host = ${CEPH_MON_HOST}
EOF

# Create mount points
mkdir -p /nas

# Create mount script
cat > /usr/local/bin/mount-cephfs.sh << EOF
#!/bin/bash

# Check if CephFS is already mounted
if ! mount | grep -q "/nas"; then
    # Mount the CephFS filesystem with name "nas"
    echo "Mounting CephFS as /nas..."
    mount -t ceph ${CEPH_MON_HOST}:/ /nas \
        -o name=admin,fs=${CEPH_FS_NAME},_netdev,noatime

    # Create media directory if it doesn't exist
    mkdir -p /nas/media
fi
EOF

chmod +x /usr/local/bin/mount-cephfs.sh

# Create systemd service for mounting CephFS
cat > /etc/systemd/system/cephfs-mount.service << EOF
[Unit]
Description=Mount CephFS with name "nas"
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mount-cephfs.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Create Nomad client config with reference to nas volume
cat > /etc/nomad.d/nomad.hcl << EOF
# Nomad Client Configuration

data_dir = "/opt/nomad/data"
plugin_dir = "/opt/nomad/plugins"

server {
  enabled = false
}

client {
  enabled = true

  # Make sure to add host volumes for Ceph storage
  host_volume "nas" {
    path = "/nas"
    read_only = false
  }

  # For backward compatibility
  host_volume "ceph-media" {
    path = "/mnt/ceph/media"
    read_only = false
  }
}

consul {
  address = "127.0.0.1:8500"
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
}

# Enable Docker driver
plugin "docker" {
  config {
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
EOF

# Create Consul client config
cat > /etc/consul.d/consul.hcl << EOF
# Consul Client Configuration

data_dir = "/opt/consul/data"
client_addr = "0.0.0.0"
ui_config {
  enabled = true
}

server = false
encrypt = "PMtCF2Q2mJdN/+yDXSDbMg=="

retry_join = ["REPLACE_WITH_IP_ADDRESS"]
EOF

# Add CephFS mount to fstab for persistent mounting
echo "${CEPH_MON_HOST}:/ /nas ceph name=admin,fs=${CEPH_FS_NAME},_netdev,noatime 0 0" >> /etc/fstab

# Enable services
systemctl daemon-reload
systemctl enable cephfs-mount.service
systemctl enable nomad
systemctl enable consul
systemctl enable docker

# Start the CephFS mount right away
/usr/local/bin/mount-cephfs.sh

# Create test file to verify mount
if mount | grep -q "/nas"; then
    echo "CephFS mount successful!"
    echo "This is a test file created during provisioning" > /nas/test_file.txt
    echo "Mount is working properly" >> /nas/test_file.txt
    ls -la /nas/
else
    echo "WARNING: CephFS mount not found. Check configuration."
fi

# Clean up
apt-get clean

echo "Nomad client setup complete!"
