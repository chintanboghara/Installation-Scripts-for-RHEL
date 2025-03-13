#!/bin/bash

# Script to install Redis on RHEL (versions 7, 8, 9)
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
REDIS_PORT=6379

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

# Install Redis
echo "Installing Redis..."
if [ "$RHEL_VERSION" == "7" ]; then
    # RHEL 7 uses EPEL for Redis
    yum install -y epel-release || print_error "Failed to install EPEL repository"
    yum install -y redis || print_error "Failed to install Redis on RHEL 7"
elif [ "$RHEL_VERSION" == "8" ] || [ "$RHEL_VERSION" == "9" ]; then
    # RHEL 8/9 use the official Redis repository
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-"$RHEL_VERSION".noarch.rpm || {
        print_error "Failed to install EPEL repository"
    }
    yum module enable -y redis || print_error "Failed to enable Redis module"
    yum install -y redis || print_error "Failed to install Redis"
else
    print_error "Unsupported RHEL version: $RHEL_VERSION"
fi

# Configure Redis (optional: bind to localhost and set port)
echo "Configuring Redis..."
sed -i "s/bind 127.0.0.1/bind 0.0.0.0/" /etc/redis.conf || {
    echo "Warning: Failed to update Redis bind address; default will be used"
}
sed -i "s/port 6379/port $REDIS_PORT/" /etc/redis.conf || {
    echo "Warning: Failed to update Redis port; default 6379 will be used"
}

# Set permissions
chown redis:redis /etc/redis.conf
chmod 640 /etc/redis.conf

# Start and enable Redis service
echo "Starting Redis service..."
systemctl start redis || print_error "Failed to start Redis"
systemctl enable redis || print_error "Failed to enable Redis"

# Configure SELinux (if enabled)
if sestatus | grep -q "enabled"; then
    echo "Configuring SELinux for Redis..."
    setsebool -P httpd_can_network_connect_db 1 2>/dev/null || {
        echo "Warning: Failed to set SELinux boolean"
    }
    semanage port -a -t redis_port_t -p tcp "$REDIS_PORT" 2>/dev/null || {
        echo "Warning: Failed to set SELinux port; port $REDIS_PORT may not work"
    }
fi

# Configure firewall (if active)
if systemctl is-active firewalld &>/dev/null; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port="$REDIS_PORT/tcp" || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Verify Redis installation
echo "Verifying Redis installation..."
if systemctl is-active redis &>/dev/null; then
    REDIS_VERSION=$(redis-server --version | grep -oP 'v=\K[0-9.]+')
    print_success "Redis installed: Version $REDIS_VERSION"
else
    print_error "Redis verification failed"
fi

# Test Redis connectivity
echo "Testing Redis connectivity..."
redis-cli -p "$REDIS_PORT" ping | grep -q "PONG" || {
    print_error "Redis is running but not responding on port $REDIS_PORT"
}

# Final success message and usage instructions
print_success "Redis installation completed successfully!"
echo "------------------------------------------------"
echo "Redis version: $REDIS_VERSION"
echo "Access Redis with: redis-cli -p $REDIS_PORT"
echo "Configuration file: /etc/redis.conf"
echo "Data directory: /var/lib/redis"
echo "Service: systemctl {start|stop|restart} redis"
echo "Example commands:"
echo "  - Set key: redis-cli SET mykey 'Hello'"
echo "  - Get key: redis-cli GET mykey"
echo "Documentation: https://redis.io/documentation"
echo "------------------------------------------------"

exit $SUCCESS
