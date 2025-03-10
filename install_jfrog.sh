#!/bin/bash

# Script to install JFrog Artifactory OSS on RHEL (versions 7, 8, 9)
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
ARTIFACTORY_VERSION="7.77.10"  # Latest OSS version as of March 2025; adjust as needed
ARTIFACTORY_PORT=8081          # Default Artifactory port
JAVA_VERSION="17"              # OpenJDK version compatible with Artifactory 7.x

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

# Install required dependencies
echo "Installing dependencies..."
yum install -y curl wget java-"$JAVA_VERSION"-openjdk || {
    print_error "Failed to install dependencies (curl, wget, OpenJDK $JAVA_VERSION)"
}

# Verify Java installation
if command -v java &>/dev/null; then
    JAVA_VERSION_INSTALLED=$(java -version 2>&1 | head -n 1)
    print_success "Java installed: $JAVA_VERSION_INSTALLED"
else
    print_error "Java installation failed"
fi

# Set JAVA_HOME environment variable
JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
echo "export JAVA_HOME=$JAVA_HOME" >> /etc/environment
source /etc/environment
echo "JAVA_HOME set to: $JAVA_HOME"

# Add JFrog Artifactory repository
echo "Configuring JFrog Artifactory repository..."
cat > /etc/yum.repos.d/jfrog-artifactory.repo << EOF
[jfrog-artifactory]
name=JFrog Artifactory
baseurl=https://releases.jfrog.io/artifactory/artifactory-rpms/rhel/\$releasever/
enabled=1
gpgcheck=0
EOF

# Install JFrog Artifactory
echo "Installing JFrog Artifactory $ARTIFACTORY_VERSION..."
yum install -y jfrog-artifactory-oss-"$ARTIFACTORY_VERSION" || {
    print_error "Failed to install JFrog Artifactory"
}

# Configure Artifactory port (optional)
echo "Configuring Artifactory to listen on port $ARTIFACTORY_PORT..."
sed -i "s/8081/$ARTIFACTORY_PORT/" /opt/jfrog/artifactory/app/bin/artifactory.config.xml || {
    echo "Warning: Failed to update Artifactory port; default port 8081 will be used"
}

# Set permissions
chown -R artifactory:artifactory /opt/jfrog/artifactory
chmod -R 750 /opt/jfrog/artifactory

# Start and enable Artifactory service
echo "Starting Artifactory service..."
systemctl start artifactory || print_error "Failed to start Artifactory"
systemctl enable artifactory || print_error "Failed to enable Artifactory"

# Configure firewall (if active)
if systemctl is-active firewalld &>/dev/null; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port="$ARTIFACTORY_PORT/tcp" || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Wait for Artifactory to start (up to 60 seconds)
echo "Waiting for Artifactory to start..."
timeout 60s bash -c "until curl -s http://localhost:$ARTIFACTORY_PORT/artifactory >/dev/null; do sleep 1; done" || {
    print_error "Artifactory failed to start within 60 seconds"
}

# Verify Artifactory installation
if systemctl is-active artifactory &>/dev/null; then
    ARTIFACTORY_VERSION_INSTALLED=$(rpm -q jfrog-artifactory-oss | grep -oP '\K\d+\.\d+\.\d+')
    print_success "JFrog Artifactory installed and running: Version $ARTIFACTORY_VERSION_INSTALLED"
else
    print_error "Artifactory verification failed"
fi

# Final success message and usage instructions
print_success "JFrog Artifactory installation completed successfully!"
echo "------------------------------------------------"
echo "Artifactory version: $ARTIFACTORY_VERSION_INSTALLED"
echo "Access Artifactory at: http://<server-ip>:$ARTIFACTORY_PORT/artifactory"
echo "Default credentials: admin / password"
echo "Configuration directory: /opt/jfrog/artifactory/var/etc"
echo "Service: systemctl {start|stop|restart} artifactory"
echo "Logs: /opt/jfrog/artifactory/var/log"
echo "Documentation: https://jfrog.com/help/"
echo "Next steps: Log in and configure repositories"
echo "------------------------------------------------"

exit $SUCCESS
