#!/bin/bash

# Script to install AWS CLI v2 on RHEL
# Can be run as root or regular user (installs system-wide or user-specific)

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
AWS_CLI_VERSION="2"  # Installs latest AWS CLI v2

# Function to print error messages
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit $ERROR
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Check RHEL version
if ! [ -f /etc/redhat-release ]; then
    print_error "This script is designed for RHEL systems only"
fi

RHEL_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
echo "Detected RHEL version: $RHEL_VERSION"

# Determine installation type
if [[ $EUID -eq 0 ]]; then
    echo "Running as root, installing AWS CLI system-wide"
    INSTALL_DIR="/usr/local/aws-cli"
    BIN_DIR="/usr/local/bin"
else
    echo "Running as non-root user, installing AWS CLI in home directory"
    INSTALL_DIR="$HOME/.aws-cli"
    BIN_DIR="$HOME/bin"
    mkdir -p "$BIN_DIR"
    PATH_UPDATE="export PATH=\$PATH:$BIN_DIR"
fi

# Update system packages
echo "Updating system packages..."
if [[ $EUID -eq 0 ]]; then
    yum update -y || print_error "Failed to update system packages"
else
    echo "Skipping system update (requires root privileges)"
fi

# Install required dependencies
echo "Installing dependencies..."
if [[ $EUID -eq 0 ]]; then
    yum install -y unzip curl || {
        print_error "Failed to install dependencies"
    }
else
    command -v unzip >/dev/null 2>&1 || print_error "unzip is required but not installed"
    command -v curl >/dev/null 2>&1 || print_error "curl is required but not installed"
fi

# Download AWS CLI v2
echo "Downloading AWS CLI v2..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || {
    print_error "Failed to download AWS CLI"
}

# Install AWS CLI
echo "Installing AWS CLI..."
unzip -q awscliv2.zip || print_error "Failed to unzip AWS CLI package"
./aws/install --bin-dir "$BIN_DIR" --install-dir "$INSTALL_DIR" --update || {
    print_error "Failed to install AWS CLI"
}

# Clean up
rm -rf aws awscliv2.zip

# Update PATH for non-root user
if [[ $EUID -ne 0 ]] && [ -n "$PATH_UPDATE" ]; then
    echo "Updating PATH in .bashrc..."
    echo "$PATH_UPDATE" >> "$HOME/.bashrc"
fi

# Verify installation
echo "Verifying AWS CLI installation..."
if "$BIN_DIR/aws" --version >/dev/null 2>&1; then
    AWS_VERSION=$("$BIN_DIR/aws" --version)
    print_success "AWS CLI installed successfully: $AWS_VERSION"
else
    print_error "AWS CLI installation verification failed"
fi

# Test basic functionality
echo "Testing AWS CLI..."
"$BIN_DIR/aws" help >/dev/null || {
    print_error "AWS CLI basic test failed"
}

print_success "AWS CLI installation completed successfully!"
echo "------------------------------------------------"
if [[ $EUID -eq 0 ]]; then
    echo "AWS CLI installed system-wide at: $INSTALL_DIR"
    echo "Executable: $BIN_DIR/aws"
else
    echo "AWS CLI installed in: $INSTALL_DIR"
    echo "Executable: $BIN_DIR/aws"
    echo "Run 'source ~/.bashrc' or log out/in to update PATH"
fi
echo "Configure with: aws configure"
echo "Required: AWS Access Key ID, Secret Access Key, region"
echo "Documentation: https://docs.aws.amazon.com/cli/latest/userguide/"
echo "------------------------------------------------"

exit $SUCCESS
