#!/bin/bash

# Script to install Terraform on RHEL
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
    echo "Warning: Running as non-root user, installing Terraform in user directory"
    INSTALL_DIR="$HOME/bin"
    PATH_UPDATE="export PATH=\$PATH:$HOME/bin"
else
    INSTALL_DIR="/usr/local/bin"
    PATH_UPDATE=""
fi

# Check RHEL version
if ! [ -f /etc/redhat-release ]; then
    print_error "This script is designed for RHEL systems only"
fi

RHEL_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
echo "Detected RHEL version: $RHEL_VERSION"

# Install required dependencies
echo "Installing dependencies..."
yum install -y unzip wget || {
    print_error "Failed to install dependencies"
}

# Get the latest Terraform version
echo "Fetching latest Terraform version..."
LATEST_VERSION=$(curl -s https://releases.hashicorp.com/terraform/ | \
    grep -oP 'terraform_\K[0-9]+\.[0-9]+\.[0-9]+' | \
    sort -Vr | head -n 1)

if [ -z "$LATEST_VERSION" ]; then
    print_error "Failed to determine latest Terraform version"
fi

echo "Latest Terraform version: $LATEST_VERSION"

# Define download URL
DOWNLOAD_URL="https://releases.hashicorp.com/terraform/${LATEST_VERSION}/terraform_${LATEST_VERSION}_linux_amd64.zip"

# Create temporary directory
TEMP_DIR=$(mktemp -d) || print_error "Failed to create temporary directory"
cd "$TEMP_DIR" || print_error "Failed to change to temporary directory"

# Download Terraform
echo "Downloading Terraform v$LATEST_VERSION..."
wget -q "$DOWNLOAD_URL" -O terraform.zip || {
    print_error "Failed to download Terraform"
}

# Verify checksum (optional but recommended)
echo "Downloading checksum file..."
wget -q "https://releases.hashicorp.com/terraform/${LATEST_VERSION}/terraform_${LATEST_VERSION}_SHA256SUMS" -O terraform.sha256 || {
    echo "Warning: Failed to download checksum file, skipping verification"
}

if [ -f "terraform.sha256" ]; then
    echo "Verifying download..."
    grep "terraform_${LATEST_VERSION}_linux_amd64.zip" terraform.sha256 | \
        sha256sum -c - || {
        print_error "Checksum verification failed"
    }
    print_success "Checksum verification passed"
fi

# Install Terraform
echo "Installing Terraform..."
unzip -q terraform.zip || print_error "Failed to unzip Terraform package"
mv terraform "$INSTALL_DIR/" || print_error "Failed to move Terraform binary"

# Clean up
cd / || print_error "Failed to return to root directory"
rm -rf "$TEMP_DIR"

# Ensure executable permissions
chmod +x "$INSTALL_DIR/terraform" || print_error "Failed to set executable permissions"

# Verify installation
echo "Verifying Terraform installation..."
if "$INSTALL_DIR/terraform" version >/dev/null 2>&1; then
    TERRAFORM_VERSION=$("$INSTALL_DIR/terraform" version | head -n 1)
    print_success "Terraform installed successfully: $TERRAFORM_VERSION"
else
    print_error "Terraform installation verification failed"
fi

# Update PATH if non-root installation
if [ -n "$PATH_UPDATE" ]; then
    echo "Adding Terraform to user PATH..."
    echo "$PATH_UPDATE" >> "$HOME/.bashrc"
    print_success "Terraform installed in $INSTALL_DIR"
    echo "Note: Run 'source ~/.bashrc' or log out/in to update your PATH"
else
    print_success "Terraform installed system-wide in $INSTALL_DIR"
fi

# Test Terraform
echo "Testing Terraform installation..."
"$INSTALL_DIR/terraform" -help >/dev/null || {
    print_error "Terraform basic test failed"
}

print_success "Terraform installation completed successfully!"
echo "To get started, run: terraform init in your project directory"
exit $SUCCESS
