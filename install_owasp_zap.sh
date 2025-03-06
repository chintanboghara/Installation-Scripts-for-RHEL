#!/bin/bash

# Script to install OWASP ZAP on RHEL via Snap
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
ZAP_VERSION="latest"  # Snap installs latest stable by default
SNAP_VERSION="latest" # Uses latest Snap package

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

# Check if version is supported (7.6+ or 8+)
RHEL_MAJOR=$(echo "$RHEL_VERSION" | cut -d'.' -f1)
RHEL_MINOR=$(echo "$RHEL_VERSION" | cut -d'.' -f2)
if [ "$RHEL_MAJOR" -lt 7 ] || { [ "$RHEL_MAJOR" -eq 7 ] && [ "$RHEL_MINOR" -lt 6 ]; }; then
    print_error "RHEL 7.6 or higher is required for Snap support"
fi

# Update system packages
echo "Updating system packages..."
yum update -y || print_error "Failed to update system packages"

# Install EPEL repository (required for Snap)
echo "Installing EPEL repository..."
if [ "$RHEL_MAJOR" -eq 7 ]; then
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm || {
        print_error "Failed to install EPEL for RHEL 7"
    }
elif [ "$RHEL_MAJOR" -eq 8 ]; then
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || {
        print_error "Failed to install EPEL for RHEL 8"
    }
elif [ "$RHEL_MAJOR" -eq 9 ]; then
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm || {
        print_error "Failed to install EPEL for RHEL 9"
    }
else
    print_error "Unsupported RHEL version for EPEL installation"
fi

# Install Snapd
echo "Installing Snapd..."
yum install -y snapd || print_error "Failed to install Snapd"

# Enable Snapd socket
systemctl enable --now snapd.socket || print_error "Failed to enable Snapd socket"
systemctl start snapd.socket || print_error "Failed to start Snapd socket"

# Create symbolic link for classic Snap support
echo "Enabling classic Snap support..."
ln -s /var/lib/snapd/snap /snap 2>/dev/null || {
    echo "Warning: Could not create Snap symlink, may already exist"
}

# Wait for Snapd to be ready (up to 30 seconds)
echo "Waiting for Snapd to initialize..."
timeout 30s bash -c "until snap version >/dev/null 2>&1; do sleep 1; done" || {
    print_error "Snapd failed to initialize within 30 seconds"
}

# Install OWASP ZAP via Snap
echo "Installing OWASP ZAP..."
snap install zaproxy --classic || print_error "Failed to install OWASP ZAP"

# Verify installation
echo "Verifying OWASP ZAP installation..."
if command -v zaproxy >/dev/null 2>&1; then
    ZAP_VERSION_CHECK=$(zaproxy --version 2>/dev/null || echo "Version check not available")
    print_success "OWASP ZAP installed successfully: $ZAP_VERSION_CHECK"
else
    print_error "OWASP ZAP installation verification failed"
fi

# Configure basic ZAP settings (optional)
ZAP_DIR="/snap/zaproxy/current"
if [ -d "$ZAP_DIR" ]; then
    echo "ZAP installed via Snap at $ZAP_DIR"
fi

print_success "OWASP ZAP installation completed successfully!"
echo "------------------------------------------------"
echo "Run ZAP with: zaproxy"
echo "For GUI: zaproxy -g"
echo "Documentation: https://www.zaproxy.org/docs/"
echo "Note: You may need to log out and back in for Snap paths to update"
echo "------------------------------------------------"

exit $SUCCESS
