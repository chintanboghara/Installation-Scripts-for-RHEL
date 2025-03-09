#!/bin/bash

# Script to install Git on RHEL (versions 7, 8, 9)
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
    RHEL_VERSION=$(cat /etc/redhat-release | grep -oP ' release \K\d+')
else
    print_error "This script is designed for RHEL systems only"
fi

echo "Detected RHEL version: $RHEL_VERSION"

# Update system packages
echo "Updating system packages..."
yum update -y || print_error "Failed to update system packages"

# Install Git
echo "Installing Git..."
if [ "$RHEL_VERSION" == "7" ] || [ "$RHEL_VERSION" == "8" ] || [ "$RHEL_VERSION" == "9" ]; then
    yum install -y git || print_error "Failed to install Git"
else
    print_error "Unsupported RHEL version: $RHEL_VERSION"
fi

# Verify Git installation
if command -v git &>/dev/null; then
    GIT_VERSION=$(git --version)
    print_success "Git installed: $GIT_VERSION"
else
    print_error "Git installation failed"
fi

# Install additional Git tools (optional)
echo "Installing additional Git tools (git-core)..."
yum install -y git-core 2>/dev/null || {
    echo "Note: git-core not available, likely included in git package"
}

# Configure basic Git settings (optional, for root user)
echo "Configuring basic Git settings for root..."
git config --global user.name "root" || {
    echo "Warning: Failed to set Git user name"
}
git config --global user.email "root@$(hostname)" || {
    echo "Warning: Failed to set Git user email"
}
git config --global core.editor "nano" || {
    echo "Warning: Failed to set Git editor"
}

# Test Git functionality
echo "Testing Git..."
mkdir -p /tmp/git-test
cd /tmp/git-test || print_error "Failed to change to test directory"
git init &>/dev/null || print_error "Failed to initialize Git repository"
echo "Hello from Git" > test.txt
git add test.txt &>/dev/null || print_error "Failed to stage file in Git"
git commit -m "Initial commit" &>/dev/null || print_error "Failed to commit in Git"
rm -rf /tmp/git-test

# Final success message and usage instructions
print_success "Git installation and setup completed successfully!"
echo "------------------------------------------------"
echo "Git version: $GIT_VERSION"
echo "Run 'git --help' for commands"
echo "Configure user settings: git config --global user.name 'Your Name'"
echo "                        git config --global user.email 'your.email@example.com'"
echo "Example: git clone <repository-url>"
echo "Documentation: https://git-scm.com/doc"
echo "------------------------------------------------"

exit $SUCCESS
