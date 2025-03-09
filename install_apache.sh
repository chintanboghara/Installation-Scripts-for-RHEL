#!/bin/bash

# Script to install Apache HTTP Server (httpd) on RHEL (versions 7, 8, 9)
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
APACHE_PORT=80

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

# Install Apache
echo "Installing Apache HTTP Server..."
if [ "$RHEL_VERSION" == "7" ] || [ "$RHEL_VERSION" == "8" ] || [ "$RHEL_VERSION" == "9" ]; then
    yum install -y httpd || print_error "Failed to install httpd"
else
    print_error "Unsupported RHEL version: $RHEL_VERSION"
fi

# Configure Apache port (if different from default)
if [ "$APACHE_PORT" -ne 80 ]; then
    echo "Configuring Apache to listen on port $APACHE_PORT..."
    sed -i "s/Listen 80/Listen $APACHE_PORT/" /etc/httpd/conf/httpd.conf || {
        echo "Warning: Failed to update Apache port; default port 80 will be used"
    }
fi

# Create a basic welcome page
echo "Creating welcome page..."
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Apache on RHEL</title>
</head>
<body>
    <h1>Apache Installed Successfully!</h1>
    <p>This is a test page running on RHEL $RHEL_VERSION</p>
</body>
</html>
EOF

# Set permissions
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

# Start and enable Apache service
echo "Starting Apache service..."
systemctl start httpd || print_error "Failed to start Apache"
systemctl enable httpd || print_error "Failed to enable Apache"

# Configure SELinux (if enabled)
if sestatus | grep -q "enabled"; then
    echo "Configuring SELinux for Apache..."
    setsebool -P httpd_enable_homedirs true 2>/dev/null || {
        echo "Warning: Failed to set SELinux boolean; may affect access"
    }
    chcon -R -t httpd_sys_content_t /var/www/html/ 2>/dev/null || {
        echo "Warning: Failed to set SELinux context; may affect access"
    }
fi

# Configure firewall (if active)
if systemctl is-active firewalld &>/dev/null; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port="$APACHE_PORT/tcp" || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Verify Apache installation
echo "Verifying Apache installation..."
if systemctl is-active httpd &>/dev/null; then
    APACHE_VERSION=$(httpd -v | grep -oP 'Server version: Apache/\K[0-9.]+')
    print_success "Apache installed: Version $APACHE_VERSION"
else
    print_error "Apache verification failed"
fi

# Test Apache accessibility
echo "Testing Apache accessibility..."
curl -s "http://localhost:$APACHE_PORT" | grep -q "Apache Installed Successfully" || {
    print_error "Apache is running but not accessible on port $APACHE_PORT"
}

# Final success message and usage instructions
print_success "Apache installation completed successfully!"
echo "------------------------------------------------"
echo "Apache version: $APACHE_VERSION"
echo "Access Apache at: http://<server-ip>:$APACHE_PORT"
echo "Configuration file: /etc/httpd/conf/httpd.conf"
echo "Web root: /var/www/html"
echo "Logs: /var/log/httpd"
echo "Service: systemctl {start|stop|restart} httpd"
echo "Documentation: https://httpd.apache.org/docs/"
echo "------------------------------------------------"

exit $SUCCESS
