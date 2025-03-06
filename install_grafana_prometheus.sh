#!/bin/bash

# Script to install Grafana and Prometheus on RHEL
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
GRAFANA_VERSION="10.4.1"       # Latest stable as of March 2025
PROMETHEUS_VERSION="2.50.1"    # Latest stable as of March 2025
PROMETHEUS_USER="prometheus"
PROMETHEUS_HOME="/opt/prometheus"
GRAFANA_PORT=3000
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
yum install -y fontconfig urw-fonts wget unzip || {
    print_error "Failed to install dependencies"
}

### Prometheus Installation ###
echo "Starting Prometheus installation..."

# Create Prometheus user and directories
useradd -r -s /bin/nologin "$PROMETHEUS_USER" || {
    print_error "Failed to create Prometheus user"
}
mkdir -p "$PROMETHEUS_HOME" /var/lib/prometheus || {
    print_error "Failed to create Prometheus directories"
}

# Download and install Prometheus
wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
    -O prometheus.tar.gz || {
    print_error "Failed to download Prometheus"
}
tar xzf prometheus.tar.gz || print_error "Failed to extract Prometheus"
mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus "$PROMETHEUS_HOME/"
mv prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool "$PROMETHEUS_HOME/"
cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus.yml "$PROMETHEUS_HOME/"
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64 prometheus.tar.gz

# Set Prometheus permissions
chown -R "$PROMETHEUS_USER":"$PROMETHEUS_USER" "$PROMETHEUS_HOME" /var/lib/prometheus
chmod -R 750 "$PROMETHEUS_HOME"

# Configure Prometheus
cat > "$PROMETHEUS_HOME/prometheus.yml" << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:$PROMETHEUS_PORT']
EOF

# Create Prometheus systemd service
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
    --web.listen-address=0.0.0.0:$PROMETHEUS_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

### Grafana Installation ###
echo "Starting Grafana installation..."

# Add Grafana repository
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
yum install -y grafana-$GRAFANA_VERSION || {
    print_error "Failed to install Grafana"
}

# Configure Grafana
sed -i "s/;http_port = 3000/http_port = $GRAFANA_PORT/" /etc/grafana/grafana.ini
sed -i 's/;http_addr =/http_addr = 0.0.0.0/' /etc/grafana/grafana.ini

# Start services
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start prometheus || print_error "Failed to start Prometheus"
systemctl enable prometheus || print_error "Failed to enable Prometheus"
systemctl start grafana-server || print_error "Failed to start Grafana"
systemctl enable grafana-server || print_error "Failed to enable Grafana"

# Configure firewall (if active)
if systemctl is-active firewalld >/dev/null 2>&1; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port="$PROMETHEUS_PORT/tcp" || {
        echo "Warning: Failed to configure Prometheus firewall"
    }
    firewall-cmd --permanent --add-port="$GRAFANA_PORT/tcp" || {
        echo "Warning: Failed to configure Grafana firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Wait for services to start
echo "Waiting for services to initialize..."
timeout 30s bash -c "until curl -s http://localhost:$PROMETHEUS_PORT/-/healthy >/dev/null; do sleep 1; done" || {
    print_error "Prometheus failed to start within 30 seconds"
}
timeout 30s bash -c "until curl -s http://localhost:$GRAFANA_PORT >/dev/null; do sleep 1; done" || {
    print_error "Grafana failed to start within 30 seconds"
}

# Verify installations
echo "Verifying installations..."
if systemctl is-active prometheus >/dev/null 2>&1; then
    PROMETHEUS_VERSION_CHECK=$("$PROMETHEUS_HOME/prometheus" --version 2>&1 | head -n 1)
    print_success "Prometheus installed: $PROMETHEUS_VERSION_CHECK"
else
    print_error "Prometheus verification failed"
fi

if systemctl is-active grafana-server >/dev/null 2>&1; then
    GRAFANA_VERSION_CHECK=$(grafana-server --version 2>/dev/null)
    print_success "Grafana installed: $GRAFANA_VERSION_CHECK"
else
    print_error "Grafana verification failed"
fi

print_success "Installation completed successfully!"
echo "------------------------------------------------"
echo "Prometheus: http://<server-ip>:$PROMETHEUS_PORT"
echo "Grafana: http://<server-ip>:$GRAFANA_PORT"
echo "Grafana credentials: admin/admin (change after login)"
echo "Prometheus config: $PROMETHEUS_HOME/prometheus.yml"
echo "Grafana config: /etc/grafana/grafana.ini"
echo "------------------------------------------------"
echo "Next steps:"
echo "1. Login to Grafana and add Prometheus as a data source"
echo "2. Configure URL: http://localhost:$PROMETHEUS_PORT"

exit $SUCCESS
