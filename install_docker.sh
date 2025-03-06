#!/bin/bash

# Script to install Docker on RHEL
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
yum install -y yum-utils device-mapper-persistent-data lvm2 || {
    print_error "Failed to install dependencies"
}

# Remove any existing Docker installations
echo "Removing any existing Docker installations..."
yum remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine \
    podman \
    runc 2>/dev/null

# Configure Docker repository
echo "Configuring Docker repository..."
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || {
    print_error "Failed to add Docker repository"
}

# Adjust repo for RHEL (uses CentOS repo as base)
sed -i 's/centos/rhel/g' /etc/yum.repos.d/docker-ce.repo
sed -i "s/\$releasever/${RHEL_VERSION%%.*}/g" /etc/yum.repos.d/docker-ce.repo

# Install Docker
echo "Installing Docker..."
yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || {
    print_error "Failed to install Docker"
}

# Start and enable Docker service
echo "Starting Docker service..."
systemctl start docker || print_error "Failed to start Docker service"
systemctl enable docker || print_error "Failed to enable Docker service"

# Verify Docker installation
echo "Verifying Docker installation..."
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker installed successfully: $DOCKER_VERSION"
else
    print_error "Docker installation verification failed"
fi

# Add current user to docker group (optional)
if [ "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    echo "Adding $SUDO_USER to docker group..."
    usermod -aG docker "$SUDO_USER" || {
        echo "Warning: Failed to add user to docker group"
    }
    print_success "User $SUDO_USER added to docker group (relogin required)"
fi

# Test Docker installation
echo "Testing Docker installation..."
docker run hello-world || {
    print_error "Docker test run failed"
}

# Configure Docker daemon (optional basic configuration)
echo "Setting up basic Docker configuration..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << EOL
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOL

systemctl restart docker || print_error "Failed to restart Docker after configuration"

print_success "Docker installation and configuration completed successfully!"
echo "To use Docker as a non-root user, log out and log back in"
exit $SUCCESS
