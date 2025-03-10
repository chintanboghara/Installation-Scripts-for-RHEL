#!/bin/bash

# Script to install Trivy vulnerability scanner on RHEL (versions 7, 8, 9)
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
TRIVY_VERSION="latest"  # Use 'latest' or specify a version like '0.50.1'

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

# Add Trivy repository
echo "Configuring Trivy repository..."
yum-config-manager --add-repo https://aquasecurity.github.io/trivy-repo/rpm/releases/rhel/"$RHEL_VERSION"/trivy.repo || {
    print_error "Failed to add Trivy repository"
}

# Install Trivy
echo "Installing Trivy..."
if [ "$TRIVY_VERSION" == "latest" ]; then
    yum install -y trivy || print_error "Failed to install Trivy"
else
    yum install -y trivy-"$TRIVY_VERSION" || print_error "Failed to install Trivy version $TRIVY_VERSION"
fi

# Verify Trivy installation
echo "Verifying Trivy installation..."
if command -v trivy &>/dev/null; then
    TRIVY_VERSION_INSTALLED=$(trivy --version | grep -oP 'Version: \K[0-9.]+')
    print_success "Trivy installed: Version $TRIVY_VERSION_INSTALLED"
else
    print_error "Trivy installation failed"
fi

# Test Trivy functionality
echo "Testing Trivy..."
trivy --version &>/dev/null || print_error "Trivy functionality test failed"

# Update Trivy vulnerability database
echo "Updating Trivy vulnerability database..."
trivy image --download-db-only || print_error "Failed to update Trivy database"

# Final success message and usage instructions
print_success "Trivy installation completed successfully!"
echo "------------------------------------------------"
echo "Trivy version: $TRIVY_VERSION_INSTALLED"
echo "Run 'trivy' to start using the scanner"
echo "Example: trivy image docker.io/library/alpine:latest"
echo "Documentation: https://aquasecurity.github.io/trivy/latest/"
echo "Common commands:"
echo "  - Scan an image: trivy image <image-name>"
echo "  - Scan a filesystem: trivy fs /path/to/dir"
echo "  - Update database: trivy image --download-db-only"
echo "------------------------------------------------"

exit $SUCCESS
