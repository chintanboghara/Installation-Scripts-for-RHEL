#!/bin/bash

# Script to install eksctl (CLI for Amazon EKS) on RHEL (versions 7, 8, 9)
# Must be run with root privileges for system-wide installation

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
EKSCTL_VERSION="latest"  # Use 'latest' or specify a version like '0.195.0'

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
    print_error "This script must be run as root for system-wide installation"
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
yum install -y curl tar || print_error "Failed to install dependencies (curl, tar)"

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" == "x86_64" ]; then
    ARCH_TYPE="amd64"
elif [ "$ARCH" == "aarch64" ]; then
    ARCH_TYPE="arm64"
else
    print_error "Unsupported architecture: $ARCH"
fi

# Download eksctl
echo "Downloading eksctl..."
if [ "$EKSCTL_VERSION" == "latest" ]; then
    curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${ARCH_TYPE}.tar.gz" \
        -o eksctl.tar.gz || print_error "Failed to download eksctl"
else
    curl -sL "https://github.com/eksctl-io/eksctl/releases/download/v${EKSCTL_VERSION}/eksctl_Linux_${ARCH_TYPE}.tar.gz" \
        -o eksctl.tar.gz || print_error "Failed to download eksctl version $EKSCTL_VERSION"
fi

# Extract and install eksctl
echo "Installing eksctl..."
tar xzf eksctl.tar.gz -C /usr/local/bin || print_error "Failed to extract eksctl"
rm -f eksctl.tar.gz
chmod +x /usr/local/bin/eksctl || print_error "Failed to set execute permissions on eksctl"

# Verify eksctl installation
echo "Verifying eksctl installation..."
if command -v eksctl &>/dev/null; then
    EKSCTL_VERSION_INSTALLED=$(eksctl version)
    print_success "eksctl installed: $EKSCTL_VERSION_INSTALLED"
else
    print_error "eksctl installation failed"
fi

# Test eksctl functionality
echo "Testing eksctl..."
eksctl version &>/dev/null || print_error "eksctl functionality test failed"

# Final success message and usage instructions
print_success "eksctl installation completed successfully!"
echo "------------------------------------------------"
echo "eksctl version: $EKSCTL_VERSION_INSTALLED"
echo "Run 'eksctl' to start using the CLI"
echo "Prerequisites for use:"
echo "  - AWS CLI installed and configured with 'aws configure'"
echo "  - IAM permissions for EKS (see https://eksctl.io/usage/minimum-iam-policies/)"
echo "Example: eksctl create cluster --name my-cluster --region us-west-2"
echo "Documentation: https://eksctl.io/"
echo "Common commands:"
echo "  - Create cluster: eksctl create cluster"
echo "  - Get clusters: eksctl get cluster"
echo "  - Delete cluster: eksctl delete cluster --name my-cluster"
echo "------------------------------------------------"

exit $SUCCESS
