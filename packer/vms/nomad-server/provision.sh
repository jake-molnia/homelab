#!/bin/bash
set -e
# Update System with non-interactive frontend to avoid prompts
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
# Install Dependencies
apt install -y curl wget gpg coreutils sudo unzip jq dnsutils net-tools

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

# Install Docker for Nomad - more reliable method
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create Nomad server config
cat > /etc/nomad.d/nomad.hcl << 'EOF'
# Nomad Server Configuration

data_dir = "/opt/nomad/data"
plugin_dir = "/opt/nomad/plugins"

server {
  enabled = true
  bootstrap_expect = 3
  encrypt = "PGscQBiuWoXhUnknqmIXQoUCxBwafD4SbdPCXTOMWXs="
}

client {
  enabled = false
}

consul {
  address = "127.0.0.1:8500"
  auto_advertise = true
  server_auto_join = true
  client_auto_join = true
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
EOF

# Create Consul server config
cat > /etc/consul.d/consul.hcl << 'EOF'
# Consul Server Configuration

data_dir = "/opt/consul/data"
client_addr = "0.0.0.0"
ui_config {
  enabled = true
}

server = true
bootstrap_expect = 3
encrypt = "PMtCF2Q2mJdN/+yDXSDbMg=="

retry_join = ["REPLACE_WITH_IP_ADDRESS"]
EOF

# Create systemd service files if they don't already exist
systemctl enable nomad
systemctl enable consul
systemctl enable docker

# Clean up
apt-get clean
