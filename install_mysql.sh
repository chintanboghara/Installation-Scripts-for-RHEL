#!/bin/bash

# Script to install MySQL Community Server on RHEL (versions 7, 8, 9)
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
MYSQL_VERSION="8.0"  # MySQL 8.0 is the latest stable version
MYSQL_PORT=3306

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

# Install wget (needed to download MySQL repo)
echo "Installing wget..."
yum install -y wget || print_error "Failed to install wget"

# Add MySQL Yum repository
echo "Configuring MySQL $MYSQL_VERSION repository..."
if [ "$RHEL_VERSION" == "7" ]; then
    wget -q "https://dev.mysql.com/get/mysql80-community-release-el7-11.noarch.rpm" -O mysql-repo.rpm || {
        print_error "Failed to download MySQL repository for RHEL 7"
    }
elif [ "$RHEL_VERSION" == "8" ]; then
    wget -q "https://dev.mysql.com/get/mysql80-community-release-el8-10.noarch.rpm" -O mysql-repo.rpm || {
        print_error "Failed to download MySQL repository for RHEL 8"
    }
elif [ "$RHEL_VERSION" == "9" ]; then
    wget -q "https://dev.mysql.com/get/mysql80-community-release-el9-5.noarch.rpm" -O mysql-repo.rpm || {
        print_error "Failed to download MySQL repository for RHEL 9"
    }
else
    print_error "Unsupported RHEL version: $RHEL_VERSION"
fi

rpm -ivh mysql-repo.rpm || print_error "Failed to install MySQL repository RPM"
rm -f mysql-repo.rpm

# Install MySQL Server
echo "Installing MySQL Community Server $MYSQL_VERSION..."
yum install -y mysql-community-server || print_error "Failed to install MySQL Server"

# Start and enable MySQL service
echo "Starting MySQL service..."
systemctl start mysqld || print_error "Failed to start MySQL"
systemctl enable mysqld || print_error "Failed to enable MySQL"

# Configure firewall (if active)
if systemctl is-active firewalld &>/dev/null; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port="$MYSQL_PORT/tcp" || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Verify MySQL installation
echo "Verifying MySQL installation..."
if systemctl is-active mysqld &>/dev/null; then
    MYSQL_VERSION_INSTALLED=$(mysql --version | grep -oP 'Ver \K[0-9.]+')
    print_success "MySQL installed: Version $MYSQL_VERSION_INSTALLED"
else
    print_error "MySQL verification failed"
fi

# Retrieve temporary root password
echo "Retrieving temporary root password..."
TEMP_PASSWORD=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}')
if [ -z "$TEMP_PASSWORD" ]; then
    print_error "Failed to retrieve temporary root password; check /var/log/mysqld.log"
fi
print_success "Temporary root password: $TEMP_PASSWORD"

# Test MySQL connectivity
echo "Testing MySQL connectivity..."
mysql -u root -p"$TEMP_PASSWORD" --connect-expired-password -e "SHOW DATABASES;" &>/dev/null || {
    print_error "Failed to connect to MySQL with temporary password"
}

# Final success message and usage instructions
print_success "MySQL installation completed successfully!"
echo "------------------------------------------------"
echo "MySQL version: $MYSQL_VERSION_INSTALLED"
echo "Access MySQL with: mysql -u root -p"
echo "Temporary root password: $TEMP_PASSWORD"
echo "Configuration file: /etc/my.cnf"
echo "Data directory: /var/lib/mysql"
echo "Service: systemctl {start|stop|restart} mysqld"
echo "Next steps:"
echo "  1. Run 'mysql_secure_installation' to set root password and secure MySQL"
echo "  2. Log in with: mysql -u root -p'$TEMP_PASSWORD'"
echo "Documentation: https://dev.mysql.com/doc/refman/$MYSQL_VERSION/en/"
echo "------------------------------------------------"

exit $SUCCESS
