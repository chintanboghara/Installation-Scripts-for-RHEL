#!/bin/bash

# Script to install Minikube on RHEL with Docker driver
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
MINIKUBE_VERSION="latest"  # Use 'latest' or specific version like 'v1.33.1'
KUBECTL_VERSION="stable"   # Use 'stable' or specific version like 'v1.29.0'

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
yum install -y curl wget conntrack || {
    print_error "Failed to install dependencies"
}

# Install Docker (Minikube driver)
echo "Installing Docker..."
yum install -y yum-utils device-mapper-persistent-data lvm2 || {
    print_error "Failed to install Docker dependencies"
}
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo || {
    print_error "Failed to add Docker repository"
}
sed -i 's/centos/rhel/g' /etc/yum.repos.d/docker-ce.repo
sed -i "s/\$releasever/${RHEL_VERSION%%.*}/g" /etc/yum.repos.d/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io || {
    print_error "Failed to install Docker"
}
systemctl start docker || print_error "Failed to start Docker"
systemctl enable docker || print_error "Failed to enable Docker"

# Add current user to docker group (if sudo user exists)
if [ "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    usermod -aG docker "$SUDO_USER" || {
        echo "Warning: Failed to add user to docker group"
    }
fi

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || {
    print_error "Failed to download kubectl"
}
chmod +x kubectl
mv kubectl /usr/local/bin/ || print_error "Failed to install kubectl"

# Install Minikube
echo "Installing Minikube..."
if [ "$MINIKUBE_VERSION" = "latest" ]; then
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 || {
        print_error "Failed to download Minikube"
    }
else
    curl -LO https://storage.googleapis.com/minikube/releases/$MINIKUBE_VERSION/minikube-linux-amd64 || {
        print_error "Failed to download Minikube"
    }
fi
mv minikube-linux-amd64 /usr/local/bin/minikube || print_error "Failed to move Minikube binary"
chmod +x /usr/local/bin/minikube || print_error "Failed to set Minikube permissions"

# Verify installations
echo "Verifying installations..."
DOCKER_VERSION=$(docker --version)
KUBECTL_VERSION_CHECK=$(kubectl version --client --short)
MINIKUBE_VERSION_CHECK=$(minikube version --short)

if [ -z "$DOCKER_VERSION" ]; then
    print_error "Docker verification failed"
fi
if [ -z "$KUBECTL_VERSION_CHECK" ]; then
    print_error "kubectl verification failed"
fi
if [ -z "$MINIKUBE_VERSION_CHECK" ]; then
    print_error "Minikube verification failed"
fi

print_success "Docker installed: $DOCKER_VERSION"
print_success "kubectl installed: $KUBECTL_VERSION_CHECK"
print_success "Minikube installed: $MINIKUBE_VERSION_CHECK"

# Start Minikube to test
echo "Starting Minikube with Docker driver..."
minikube start --driver=docker || {
    print_error "Failed to start Minikube"
}

# Wait for Minikube to be ready (up to 60 seconds)
echo "Waiting for Minikube to be ready..."
timeout 60s bash -c "until minikube status >/dev/null 2>&1; do sleep 1; done" || {
    print_error "Minikube failed to start within 60 seconds"
}

print_success "Minikube installation and setup completed successfully!"
echo "------------------------------------------------"
echo "Minikube is running with Docker driver"
echo "Access cluster with: kubectl get nodes"
echo "Minikube dashboard: minikube dashboard"
echo "Stop Minikube: minikube stop"
echo "If run via sudo, log out/in for Docker group changes"
echo "------------------------------------------------"

exit $SUCCESS
