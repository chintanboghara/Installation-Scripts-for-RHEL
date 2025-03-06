#!/bin/bash

# Script to install Grafana OSS on RHEL
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
GRAFANA_VERSION="10.4.1"  # Latest stable version as of March 2025
GRAFANA_PORT=3000

# Function to print error messages
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit $ERROR
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Check if script is running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root"
fi

# Check RHEL version
if ! [ -f /etc/redhat-release ]; then
    print_error "This script is designed for RHEL systems only"
fi

RHEL_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
echo "Detected RHEL version: $RHEL_VERSION"

# Update system packages
echo "Updating system packages..."
yum update -y || print_error "Failed to update system packages"

# Install required dependencies
echo "Installing dependencies..."
yum install -y fontconfig urw-fonts wget || {
    print_error "Failed to install dependencies"
}

# Add Grafana repository
echo "Configuring Grafana repository..."
cat > /etc/yum.repos.d/grafana.repo << EOF
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

# Install Grafana
echo "Installing Grafana $GRAFANA_VERSION..."
yum install -y grafana-$GRAFANA_VERSION || {
    print_error "Failed to install Grafana"
}

# Start and enable Grafana service
echo "Starting Grafana service..."
systemctl start grafana-server || print_error "Failed to start Grafana service"
systemctl enable grafana-server || print_error "Failed to enable Grafana service"

# Configure basic settings
echo "Configuring Grafana..."
sed -i "s/;http_port = 3000/http_port = $GRAFANA_PORT/" /etc/grafana/grafana.ini
sed -i 's/;http_addr =/http_addr = 0.0.0.0/' /etc/grafana/grafana.ini

# Restart Grafana to apply configuration
systemctl restart grafana-server || print_error "Failed to restart Grafana after configuration"

# Configure firewall (if active)
if systemctl is-active firewalld >/dev/null 2>&1; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port="$GRAFANA_PORT/tcp" || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Wait for Grafana to start (up to 30 seconds)
echo "Waiting for Grafana to initialize..."
timeout 30s bash -c "until curl -s http://localhost:$GRAFANA_PORT >/dev/null; do sleep 1; done" || {
    print_error "Grafana failed to start within 30 seconds"
}

# Verify installation
echo "Verifying Grafana installation..."
if systemctl is-active grafana-server >/dev/null 2>&1; then
    GRAFANA_INSTALLED_VERSION=$(grafana-server --version 2>/dev/null)
    print_success "Grafana installed successfully: $GRAFANA_INSTALLED_VERSION"
else
    print_error "Grafana installation verification failed"
fi

# Print completion message with access instructions
print_success "Grafana installation completed successfully!"
echo "------------------------------------------------"
echo "Access Grafana at: http://<server-ip>:$GRAFANA_PORT"
echo "Default credentials: admin/admin"
echo "Change the admin password after first login!"
echo "Configuration file: /etc/grafana/grafana.ini"
echo "Data directory: /var/lib/grafana"
echo "------------------------------------------------"

exit $SUCCESS
