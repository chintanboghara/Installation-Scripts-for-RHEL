#!/bin/bash

# Script to install Nginx on RHEL
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
NGINX_PORT=80
NGINX_VERSION="stable"  # Use 'stable' or 'mainline' for latest versions

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
RHEL_MAJOR=$(echo "$RHEL_VERSION" | cut -d'.' -f1)
echo "Detected RHEL version: $RHEL_VERSION"

# Update system packages
echo "Updating system packages..."
yum update -y || print_error "Failed to update system packages"

# Install EPEL repository (needed for Nginx on some RHEL versions)
echo "Installing EPEL repository..."
if [ "$RHEL_MAJOR" -eq 7 ]; then
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm || {
        print_error "Failed to install EPEL for RHEL 7"
    }
elif [ "$RHEL_MAJOR" -eq 8 ]; then
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || {
        print_error "Failed to install EPEL for RHEL 8"
    }
elif [ "$RHEL_MAJOR" -eq 9 ]; then
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm || {
        print_error "Failed to install EPEL for RHEL 9"
    }
else
    print_error "Unsupported RHEL version for EPEL installation"
fi

# Add Nginx repository
echo "Configuring Nginx repository..."
cat > /etc/yum.repos.d/nginx.repo << EOF
[nginx-$NGINX_VERSION]
name=nginx $NGINX_VERSION
baseurl=https://nginx.org/packages/rhel/$RHEL_MAJOR/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=1
EOF

# Install Nginx
echo "Installing Nginx..."
yum install -y nginx || {
    print_error "Failed to install Nginx"
}

# Configure basic Nginx settings
echo "Configuring Nginx..."
sed -i "s/listen       80;/listen       $NGINX_PORT;/" /etc/nginx/nginx.conf
sed -i "s/listen       \[::\]:80;/listen       \[::\]:$NGINX_PORT;/" /etc/nginx/nginx.conf

# Create a basic welcome page
cat > /usr/share/nginx/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Nginx on RHEL</title>
</head>
<body>
    <h1>Nginx Installed Successfully!</h1>
    <p>This is a test page running on RHEL $RHEL_VERSION</p>
</body>
</html>
EOF

# Set permissions
chown -R nginx:nginx /usr/share/nginx/html
chmod -R 755 /usr/share/nginx/html

# Start and enable Nginx service
echo "Starting Nginx service..."
systemctl start nginx || print_error "Failed to start Nginx"
systemctl enable nginx || print_error "Failed to enable Nginx"

# Configure firewall (if active)
if systemctl is-active firewalld >/dev/null 2>&1; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port="$NGINX_PORT/tcp" || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Verify Nginx installation
echo "Verifying Nginx installation..."
if systemctl is-active nginx >/dev/null 2>&1; then
    NGINX_VERSION_CHECK=$(nginx -v 2>&1)
    print_success "Nginx installed successfully: $NGINX_VERSION_CHECK"
else
    print_error "Nginx verification failed"
fi

# Test Nginx accessibility
echo "Testing Nginx accessibility..."
curl -s http://localhost:$NGINX_PORT >/dev/null || {
    print_error "Nginx is running but not accessible on port $NGINX_PORT"
}

print_success "Nginx installation completed successfully!"
echo "------------------------------------------------"
echo "Access Nginx at: http://<server-ip>:$NGINX_PORT"
echo "Configuration file: /etc/nginx/nginx.conf"
echo "Web root: /usr/share/nginx/html"
echo "Logs: /var/log/nginx"
echo "------------------------------------------------"

exit $SUCCESS
