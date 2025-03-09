#!/bin/bash

# Script to install Node.js LTS on RHEL (versions 7, 8, 9)
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
NODE_VERSION="20"  # LTS version as of March 2025; adjust as needed (e.g., 18, 22)

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

# Update system packages
echo "Updating system packages..."
yum update -y || print_error "Failed to update system packages"

# Install required dependencies
echo "Installing dependencies..."
yum install -y curl || print_error "Failed to install curl"

# Add NodeSource repository
echo "Configuring NodeSource repository for Node.js $NODE_VERSION..."
if [ "$RHEL_VERSION" == "7" ]; then
    curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VERSION}.x" | bash - || {
        print_error "Failed to add NodeSource repository for RHEL 7"
    }
elif [ "$RHEL_VERSION" == "8" ]; then
    curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VERSION}.x" | bash - || {
        print_error "Failed to add NodeSource repository for RHEL 8"
    }
elif [ "$RHEL_VERSION" == "9" ]; then
    curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VERSION}.x" | bash - || {
        print_error "Failed to add NodeSource repository for RHEL 9"
    }
else
    print_error "Unsupported RHEL version: $RHEL_VERSION"
fi

# Install Node.js
echo "Installing Node.js..."
yum install -y nodejs || print_error "Failed to install Node.js"

# Verify Node.js installation
if command -v node &>/dev/null; then
    NODE_VERSION_INSTALLED=$(node --version)
    print_success "Node.js installed: $NODE_VERSION_INSTALLED"
else
    print_error "Node.js installation failed"
fi

# Verify npm installation (comes with Node.js)
if command -v npm &>/dev/null; then
    NPM_VERSION=$(npm --version)
    print_success "npm installed: $NPM_VERSION"
else
    print_error "npm installation failed"
fi

# Test Node.js functionality
echo "Testing Node.js..."
node -e "console.log('Hello from Node.js')" | grep -q "Hello" || {
    print_error "Node.js functionality test failed"
}

# Install development tools (optional)
echo "Installing Node.js development tools (build-essential equivalent)..."
yum groupinstall -y "Development Tools" || {
    echo "Warning: Failed to install development tools; continuing anyway"
}

# Final success message and usage instructions
print_success "Node.js and npm installation completed successfully!"
echo "------------------------------------------------"
echo "Node.js version: $NODE_VERSION_INSTALLED"
echo "npm version: $NPM_VERSION"
echo "Run 'node' to start Node.js"
echo "Run 'npm' to manage Node.js packages"
echo "Example: npm install <package-name>"
echo "Documentation: https://nodejs.org/en/docs/"
echo "------------------------------------------------"

exit $SUCCESS
