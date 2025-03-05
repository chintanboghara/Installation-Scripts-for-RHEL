#!/bin/bash

# Script to install Ansible on RHEL
# Must be run with root privileges

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
    print_error "This script must be run as root"
fi

# Check RHEL version
if ! [ -f /etc/redhat-release ]; then
    print_error "This script is designed for RHEL systems only"
fi

RHEL_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
echo "Detected RHEL version: $RHEL_VERSION"

# Update system packages
echo "Updating system packages..."
yum update -y || print_error "Failed to update system packages"

# Install required dependencies
echo "Installing dependencies..."
yum install -y epel-release python3 python3-pip || {
    print_error "Failed to install dependencies"
}

# Enable RHEL-specific repositories based on version
echo "Configuring repositories..."
case "$RHEL_VERSION" in
    "8"*)
        subscription-manager repos --enable ansible-2-for-rhel-8-x86_64-rpms || {
            print_error "Failed to enable Ansible repository. Ensure system is registered with subscription-manager"
        }
        ;;
    "9"*)
        subscription-manager repos --enable ansible-2-for-rhel-9-x86_64-rpms || {
            print_error "Failed to enable Ansible repository. Ensure system is registered with subscription-manager"
        }
        ;;
    *)
        echo "Warning: Unsupported RHEL version, attempting EPEL installation method"
        ;;
esac

# Install Ansible
echo "Installing Ansible..."
if ! yum install -y ansible; then
    echo "Falling back to pip installation..."
    pip3 install ansible || print_error "Failed to install Ansible via both yum and pip"
fi

# Verify installation
echo "Verifying Ansible installation..."
if command -v ansible >/dev/null 2>&1; then
    ANSIBLE_VERSION=$(ansible --version | head -n 1)
    print_success "Ansible installed successfully: $ANSIBLE_VERSION"
else
    print_error "Ansible installation verification failed"
fi

# Create basic Ansible configuration directory if it doesn't exist
echo "Setting up Ansible configuration..."
if [ ! -d "/etc/ansible" ]; then
    mkdir -p /etc/ansible
    cat > /etc/ansible/ansible.cfg << EOL
[defaults]
inventory = /etc/ansible/hosts
remote_user = root
host_key_checking = False
EOL
    cat > /etc/ansible/hosts << EOL
[local]
localhost ansible_connection=local
EOL
    print_success "Basic Ansible configuration created"
fi

# Test Ansible installation
echo "Testing Ansible installation..."
ansible all -m ping || {
    print_error "Ansible ping test failed"
}

print_success "Ansible installation and configuration completed successfully!"
exit $SUCCESS
