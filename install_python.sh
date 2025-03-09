#!/bin/bash

# Script to install Python 3 on RHEL (versions 7, 8, 9)
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

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
    RHEL_VERSION=$(cat /etc/redhat-release | grep -oP 'release \K\d+')
else
    print_error "This script is designed for RHEL systems only"
fi

echo "Detected RHEL version: $RHEL_VERSION"

# Install Python based on RHEL version
if [ "$RHEL_VERSION" == "7" ]; then
    echo "Installing EPEL repository for RHEL 7..."
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm || print_error "Failed to install EPEL repository"
    echo "Installing Python 3.6..."
    yum install -y python36 || print_error "Failed to install python36"
    PYTHON_CMD="python3.6"
    PIP_CMD="pip3.6"
elif [ "$RHEL_VERSION" == "8" ] || [ "$RHEL_VERSION" == "9" ]; then
    echo "Installing Python 3..."
    yum install -y python3 || print_error "Failed to install python3"
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
else
    print_error "Unsupported RHEL version: $RHEL_VERSION"
fi

# Verify Python installation
if command -v "$PYTHON_CMD" &>/dev/null; then
    PYTHON_VERSION=$("$PYTHON_CMD" --version)
    print_success "Python installed: $PYTHON_VERSION"
else
    print_error "Python installation failed"
fi

# Check if pip is installed; install it if necessary
if ! command -v "$PIP_CMD" &>/dev/null; then
    echo "pip not found, attempting to install..."
    if [ "$RHEL_VERSION" == "7" ]; then
        yum install -y python36-pip || print_error "Failed to install python36-pip"
    else
        yum install -y python3-pip || print_error "Failed to install python3-pip"
    fi
fi

# Verify pip installation
if command -v "$PIP_CMD" &>/dev/null; then
    PIP_VERSION=$("$PIP_CMD" --version)
    print_success "pip installed: $PIP_VERSION"
else
    print_error "Failed to install pip"
fi

# Final success message and usage instructions
print_success "Python and pip installation completed successfully!"
echo "------------------------------------------------"
echo "Use '$PYTHON_CMD' to run Python"
echo "Use '$PIP_CMD' to manage Python packages"
echo "------------------------------------------------"

exit $SUCCESS
