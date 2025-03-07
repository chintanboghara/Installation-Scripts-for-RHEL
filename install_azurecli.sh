#!/bin/bash

# Script to install Azure CLI on RHEL
# Must be run with root privileges for system-wide installation

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

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
    print_error "This script must be run as root for system-wide installation"
fi

# Check RHEL version
if ! [ -f /etc/redhat-release ]; then
    print_error "This script is designed for RHEL systems only"
fi

RHEL_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
RHEL_MAJOR=$(echo "$RHEL_VERSION" | cut -d'.' -f1)
echo "Detected RHEL version: $RHEL_VERSION"

# Update system packages
echo "Updating system packages..."
yum update -y || print_error "Failed to update system packages"

# Install required dependencies
echo "Installing dependencies..."
yum install -y curl || {
    print_error "Failed to install dependencies"
}

# Add Microsoft repository key
echo "Adding Microsoft repository key..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc || {
    print_error "Failed to import Microsoft key"
}

# Add Azure CLI repository
echo "Configuring Azure CLI repository..."
cat > /etc/yum.repos.d/azure-cli.repo << EOF
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Install Azure CLI
echo "Installing Azure CLI..."
yum install -y azure-cli || {
    print_error "Failed to install Azure CLI"
}

# Verify installation
echo "Verifying Azure CLI installation..."
if command -v az >/dev/null 2>&1; then
    AZ_VERSION=$(az --version | head -n 1)
    print_success "Azure CLI installed successfully: $AZ_VERSION"
else
    print_error "Azure CLI installation verification failed"
fi

# Test basic functionality
echo "Testing Azure CLI..."
az --help >/dev/null || {
    print_error "Azure CLI basic test failed"
}

print_success "Azure CLI installation completed successfully!"
echo "------------------------------------------------"
echo "Executable: /usr/bin/az"
echo "Configure with: az login"
echo "For service principal: az login --service-principal -u <app-id> -p <password-or-cert> --tenant <tenant>"
echo "Documentation: https://learn.microsoft.com/en-us/cli/azure/"
echo "------------------------------------------------"

exit $SUCCESS
