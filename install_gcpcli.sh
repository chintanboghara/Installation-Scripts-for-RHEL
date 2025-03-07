#!/bin/bash

# Script to install gcloud CLI on RHEL
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
yum install -y curl python3 || {
    print_error "Failed to install dependencies"
}

# Add Google Cloud SDK repository
echo "Configuring Google Cloud SDK repository..."
cat > /etc/yum.repos.d/google-cloud-sdk.repo << EOF
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el$RHEL_MAJOR-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# Install gcloud CLI
echo "Installing gcloud CLI..."
yum install -y google-cloud-cli || {
    print_error "Failed to install gcloud CLI"
}

# Verify installation
echo "Verifying gcloud CLI installation..."
if command -v gcloud >/dev/null 2>&1; then
    GCLOUD_VERSION=$(gcloud version --format='value("Google Cloud SDK")')
    print_success "gcloud CLI installed successfully: Google Cloud SDK $GCLOUD_VERSION"
else
    print_error "gcloud CLI installation verification failed"
fi

# Test basic functionality
echo "Testing gcloud CLI..."
gcloud --help >/dev/null || {
    print_error "gcloud CLI basic test failed"
}

print_success "gcloud CLI installation completed successfully!"
echo "------------------------------------------------"
echo "Executable: /usr/bin/gcloud"
echo "Initialize with: gcloud init"
echo "Login with: gcloud auth login"
echo "Set project: gcloud config set project <project-id>"
echo "Documentation: https://cloud.google.com/sdk/docs/"
echo "------------------------------------------------"

exit $SUCCESS
