#!/bin/bash

# Script to install Jenkins on RHEL
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
yum install -y wget fontconfig || {
    print_error "Failed to install basic dependencies"
}

# Install Java (Jenkins requires Java 11 or 17)
echo "Installing Java..."
if ! command -v java >/dev/null 2>&1 || ! java -version 2>&1 | grep -q "11\|17"; then
    yum install -y java-11-openjdk java-11-openjdk-devel || {
        print_error "Failed to install Java 11"
    }
fi

JAVA_VERSION=$(java -version 2>&1 | head -n 1)
print_success "Java installed: $JAVA_VERSION"

# Add Jenkins repository
echo "Configuring Jenkins repository..."
wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo || {
    print_error "Failed to download Jenkins repository"
}

rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key || {
    print_error "Failed to import Jenkins repository key"
}

# Install Jenkins
echo "Installing Jenkins..."
yum install -y jenkins || {
    print_error "Failed to install Jenkins"
}

# Start and enable Jenkins service
echo "Starting Jenkins service..."
systemctl start jenkins || print_error "Failed to start Jenkins service"
systemctl enable jenkins || print_error "Failed to enable Jenkins service"

# Wait for Jenkins to start (up to 60 seconds)
echo "Waiting for Jenkins to initialize..."
timeout 60s bash -c "until systemctl is-active jenkins >/dev/null 2>&1; do sleep 1; done" || {
    print_error "Jenkins failed to start within 60 seconds"
}

# Get initial admin password
echo "Retrieving initial admin password..."
INITIAL_PASSWORD=""
for i in {1..30}; do
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        INITIAL_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
        break
    fi
    sleep 2
done

if [ -z "$INITIAL_PASSWORD" ]; then
    print_error "Failed to retrieve initial admin password"
fi

# Adjust firewall (if firewalld is running)
if systemctl is-active firewalld >/dev/null 2>&1; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port=8080/tcp || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Verify Jenkins installation
echo "Verifying Jenkins installation..."
if systemctl is-active jenkins >/dev/null 2>&1; then
    JENKINS_VERSION=$(java -jar /usr/lib/jenkins/jenkins.war --version 2>/dev/null)
    print_success "Jenkins installed successfully: Version $JENKINS_VERSION"
else
    print_error "Jenkins installation verification failed"
fi

# Print completion message with access instructions
print_success "Jenkins installation completed successfully!"
echo "------------------------------------------------"
echo "Access Jenkins at: http://<server-ip>:8080"
echo "Initial Admin Password: $INITIAL_PASSWORD"
echo "------------------------------------------------"
echo "Save this password! You'll need it for first login"
echo "If using a firewall, ensure port 8080 is accessible"
echo "To customize Jenkins, modify /var/lib/jenkins/config.xml"

exit $SUCCESS
