#!/bin/bash

# Script to install Prometheus on RHEL
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
PROMETHEUS_VERSION="2.50.1"  # Latest stable version as of March 2025
PROMETHEUS_USER="prometheus"
PROMETHEUS_HOME="/opt/prometheus"
PROMETHEUS_PORT=9090

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
yum install -y wget || {
    print_error "Failed to install dependencies"
}

# Create Prometheus user
echo "Creating Prometheus system user..."
useradd -r -s /bin/nologin "$PROMETHEUS_USER" || {
    print_error "Failed to create Prometheus user"
}

# Create directories
echo "Creating Prometheus directories..."
mkdir -p "$PROMETHEUS_HOME" /var/lib/prometheus || {
    print_error "Failed to create directories"
}

# Download Prometheus
echo "Downloading Prometheus $PROMETHEUS_VERSION..."
wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
    -O prometheus.tar.gz || {
    print_error "Failed to download Prometheus"
}

# Extract and install
echo "Installing Prometheus..."
tar xzf prometheus.tar.gz || print_error "Failed to extract Prometheus"
mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus "$PROMETHEUS_HOME/"
mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool "$PROMETHEUS_HOME/"
cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus.yml "$PROMETHEUS_HOME/"
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64 prometheus.tar.gz

# Set permissions
chown -R "$PROMETHEUS_USER":"$PROMETHEUS_USER" "$PROMETHEUS_HOME" /var/lib/prometheus
chmod -R 750 "$PROMETHEUS_HOME"

# Create basic configuration
echo "Configuring Prometheus..."
cat > "$PROMETHEUS_HOME/prometheus.yml" << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:$PROMETHEUS_PORT']
EOF

# Create systemd service file
echo "Creating Prometheus service..."
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=$PROMETHEUS_USER
Group=$PROMETHEUS_USER
Type=simple
ExecStart=$PROMETHEUS_HOME/prometheus \
    --config.file=$PROMETHEUS_HOME/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus/ \
    --web.listen-address=0.0.0.0:$PROMETHEUS_PORT \
    --web.console.templates=$PROMETHEUS_HOME/consoles \
    --web.console.libraries=$PROMETHEUS_HOME/console_libraries
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start prometheus || print_error "Failed to start Prometheus"
systemctl enable prometheus || print_error "Failed to enable Prometheus"

# Configure firewall (if active)
if systemctl is-active firewalld >/dev/null 2>&1; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port="$PROMETHEUS_PORT/tcp" || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Wait for Prometheus to start (up to 30 seconds)
echo "Waiting for Prometheus to initialize..."
timeout 30s bash -c "until curl -s http://localhost:$PROMETHEUS_PORT/-/healthy >/dev/null; do sleep 1; done" || {
    print_error "Prometheus failed to start within 30 seconds"
}

# Verify installation
echo "Verifying Prometheus installation..."
if systemctl is-active prometheus >/dev/null 2>&1; then
    PROMETHEUS_VERSION_CHECK=$("$PROMETHEUS_HOME/prometheus" --version 2>&1 | head -n 1)
    print_success "Prometheus installed successfully: $PROMETHEUS_VERSION_CHECK"
else
    print_error "Prometheus installation verification failed"
fi

print_success "Prometheus installation completed successfully!"
echo "------------------------------------------------"
echo "Access Prometheus at: http://<server-ip>:$PROMETHEUS_PORT"
echo "Configuration file: $PROMETHEUS_HOME/prometheus.yml"
echo "Data directory: /var/lib/prometheus"
echo "------------------------------------------------"

exit $SUCCESS
