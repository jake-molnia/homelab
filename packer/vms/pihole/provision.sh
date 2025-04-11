#!/bin/bash
set -e
# Update System
apt update && apt upgrade -y
# Install Dependencies
apt install -y curl sudo
# Install Pi-hole in unattended mode
mkdir -p /etc/pihole/
cat > /etc/pihole/setupVars.conf << EOF
PIHOLE_INTERFACE=eth0
PIHOLE_DNS_1=1.1.1.1
PIHOLE_DNS_2=1.0.0.1
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=10000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSMASQ_LISTENING=single
WEBPASSWORD=
BLOCKING_ENABLED=true
PIHOLE_DOMAIN=pi.hole
WEBUIBOXEDLAYOUT=boxed
WEBTHEME=deep-midnight
EOF
curl -sSL https://install.pi-hole.net | PIHOLE_SKIP_OS_CHECK=true bash /dev/stdin --unattended
# Restart Services
systemctl restart pihole-FTL
echo "Pi-hole installation complete!"
# Install pihole list updater
# https://github.com/jacklul/pihole-updatelists
apt install -y php-cli php-sqlite3 php-curl php-intl
wget -O - https://raw.githubusercontent.com/jacklul/pihole-updatelists/master/install.sh | bash
sed -e '/pihole updateGravity/ s/^#*/#/' -i /etc/cron.d/pihole # disable piholes default automatic updates

# Configure pihole-updatelists
cat > /etc/pihole-updatelists.conf << EOF
; Pi-hole's Lists Updater configuration

; Remote list URL containing list of blocklists to import
; URLs to single lists are not supported here!
ADLISTS_URL="https://v.firebog.net/hosts/lists.php?type=tick"

; Comment string used to identify entries managed by this script
COMMENT="Managed by pihole-updatelists"

; Enable or disable updating of gravity after lists are updated
UPDATE_GRAVITY=true

; Run pihole-updatelists once after installation
EOF

# Set correct permissions
chmod 644 /etc/pihole-updatelists.conf

# Enable and start the systemd timer
systemctl enable pihole-updatelists.timer
systemctl start pihole-updatelists.timer

# Run the updater once during provisioning to load initial lists
pihole-updatelists

echo "Pi-hole updatelists installation and configuration complete!"
