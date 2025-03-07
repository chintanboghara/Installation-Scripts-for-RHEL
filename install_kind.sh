#!/bin/bash

# Script to install KinD on RHEL with Docker
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
KIND_VERSION="v0.23.0"      # Latest stable version as of March 2025
KUBECTL_VERSION="stable"    # Use 'stable' or specific version like 'v1.29.0'

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
yum install -y curl wget || {
    print_error "Failed to install dependencies"
}

# Install Docker (required for KinD)
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

# Install KinD
echo "Installing KinD $KIND_VERSION..."
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-amd64" || {
    print_error "Failed to download KinD"
}
chmod +x kind
mv kind /usr/local/bin/ || print_error "Failed to install KinD"

# Verify installations
echo "Verifying installations..."
DOCKER_VERSION=$(docker --version)
KUBECTL_VERSION_CHECK=$(kubectl version --client --short)
KIND_VERSION_CHECK=$(kind version)

if [ -z "$DOCKER_VERSION" ]; then
    print_error "Docker verification failed"
fi
if [ -z "$KUBECTL_VERSION_CHECK" ]; then
    print_error "kubectl verification failed"
fi
if [ -z "$KIND_VERSION_CHECK" ]; then
    print_error "KinD verification failed"
fi

print_success "Docker installed: $DOCKER_VERSION"
print_success "kubectl installed: $KUBECTL_VERSION_CHECK"
print_success "KinD installed: $KIND_VERSION_CHECK"

# Create a test KinD cluster
echo "Creating a test KinD cluster..."
kind create cluster --name test-cluster || {
    print_error "Failed to create KinD cluster"
}

# Wait for cluster to be ready (up to 60 seconds)
echo "Waiting for cluster to be ready..."
timeout 60s bash -c "until kubectl get nodes -o wide >/dev/null 2>&1; do sleep 1; done" || {
    print_error "KinD cluster failed to become ready within 60 seconds"
}

# Verify cluster
CLUSTER_STATUS=$(kubectl cluster-info --context kind-test-cluster 2>/dev/null)
if [ -n "$CLUSTER_STATUS" ]; then
    print_success "KinD cluster 'test-cluster' is running"
else
    print_error "Failed to verify KinD cluster"
fi

print_success "KinD installation and setup completed successfully!"
echo "------------------------------------------------"
echo "Access cluster with: kubectl get nodes --context kind-test-cluster"
echo "Delete cluster: kind delete cluster --name test-cluster"
echo "Create new cluster: kind create cluster --name <name>"
echo "If run via sudo, log out/in for Docker group changes"
echo "------------------------------------------------"

exit $SUCCESS
