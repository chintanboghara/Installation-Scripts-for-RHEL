#!/bin/bash

# Script to install HashiCorp Vault on RHEL (versions 7, 8, 9)
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
VAULT_VERSION="latest"  # Use 'latest' or specify a version like '1.16.0'
VAULT_PORT=8200
VAULT_CONFIG_DIR="/etc/vault.d"
VAULT_DATA_DIR="/opt/vault/data"

# Function to print error messages and exit
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit $ERROR
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Check if the script is running as root
if [ "$(id -u)" -ne 0 ]; then
    print_error "This script must be run as root"
fi

# Determine RHEL version
if [ -f /etc/redhat-release ]; then
    RHEL_VERSION=$(cat /etc/redhat-release | grep -oP ' release \K\d+')
else
    print_error "This script is designed for RHEL systems only"
fi

echo "Detected RHEL version: $RHEL_VERSION"

# Update system packages
echo "Updating system packages..."
yum update -y || print_error "Failed to update system packages"

# Install required dependencies
echo "Installing dependencies..."
yum install -y yum-utils curl || print_error "Failed to install dependencies"

# Add HashiCorp repository
echo "Configuring HashiCorp repository..."
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo || {
    print_error "Failed to add HashiCorp repository"
}

# Install Vault
echo "Installing HashiCorp Vault..."
if [ "$VAULT_VERSION" == "latest" ]; then
    yum install -y vault || print_error "Failed to install Vault"
else
    yum install -y vault-"$VAULT_VERSION" || print_error "Failed to install Vault version $VAULT_VERSION"
fi

# Create Vault user
echo "Creating Vault user..."
useradd --system --home "$VAULT_DATA_DIR" --shell /bin/false vault || {
    print_error "Failed to create Vault user"
}

# Create Vault directories
mkdir -p "$VAULT_CONFIG_DIR" "$VAULT_DATA_DIR" || print_error "Failed to create Vault directories"
chown vault:vault "$VAULT_DATA_DIR"
chmod 750 "$VAULT_DATA_DIR"

# Configure Vault (basic file storage backend)
echo "Configuring Vault..."
cat > "$VAULT_CONFIG_DIR/vault.hcl" << EOF
ui = true
disable_mlock = true

storage "file" {
  path = "$VAULT_DATA_DIR"
}

listener "tcp" {
  address     = "0.0.0.0:$VAULT_PORT"
  tls_disable = true
}

api_addr = "http://127.0.0.1:$VAULT_PORT"
EOF

chown vault:vault "$VAULT_CONFIG_DIR/vault.hcl"
chmod 640 "$VAULT_CONFIG_DIR/vault.hcl"

# Create systemd service file
echo "Creating Vault systemd service..."
cat > /etc/systemd/system/vault.service << EOF
[Unit]
Description=HashiCorp Vault - A tool for managing secrets
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=$VAULT_CONFIG_DIR/vault.hcl

[Service]
User=vault
Group=vault
ExecStart=/usr/bin/vault server -config=$VAULT_CONFIG_DIR/vault.hcl
ExecReload=/bin/kill --signal HUP \$MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start Vault
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start vault || print_error "Failed to start Vault"
systemctl enable vault || print_error "Failed to enable Vault"

# Configure firewall (if active)
if systemctl is-active firewalld &>/dev/null; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port="$VAULT_PORT/tcp" || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Verify Vault installation
echo "Verifying Vault installation..."
if command -v vault &>/dev/null; then
    VAULT_VERSION_INSTALLED=$(vault version)
    print_success "Vault installed: $VAULT_VERSION_INSTALLED"
else
    print_error "Vault installation failed"
fi

# Wait for Vault to start (up to 30 seconds)
echo "Waiting for Vault to start..."
timeout 30s bash -c "until curl -s http://localhost:$VAULT_PORT/v1/sys/health >/dev/null; do sleep 1; done" || {
    print_error "Vault failed to start within 30 seconds"
}

# Final success message and usage instructions
print_success "HashiCorp Vault installation completed successfully!"
echo "------------------------------------------------"
echo "Vault version: $VAULT_VERSION_INSTALLED"
echo "Access Vault UI at: http://<server-ip>:$VAULT_PORT/ui"
echo "Configuration file: $VAULT_CONFIG_DIR/vault.hcl"
echo "Data directory: $VAULT_DATA_DIR"
echo "Service: systemctl {start|stop|restart} vault"
echo "Next steps: Run 'vault operator init' to initialize Vault"
echo "Documentation: https://www.vaultproject.io/docs/"
echo "------------------------------------------------"

exit $SUCCESS
