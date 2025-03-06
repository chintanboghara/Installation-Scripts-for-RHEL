#!/bin/bash

# Script to install SonarQube on RHEL with PostgreSQL
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
SONAR_VERSION="10.4.1.88267"  # Latest community edition as of March 2025
SONAR_USER="sonarqube"
SONAR_HOME="/opt/sonarqube"
DB_NAME="sonarqube"
DB_USER="sonarqube"
DB_PASS="SonarQube123!"  # Change this in production!

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
yum install -y java-17-openjdk unzip wget || {
    print_error "Failed to install dependencies"
}

# Install PostgreSQL
echo "Installing PostgreSQL..."
yum install -y postgresql-server postgresql-contrib || {
    print_error "Failed to install PostgreSQL"
}

# Initialize PostgreSQL if not already initialized
if [ ! -d "/var/lib/pgsql/data" ]; then
    postgresql-setup initdb || print_error "Failed to initialize PostgreSQL"
fi

# Start and enable PostgreSQL
systemctl start postgresql || print_error "Failed to start PostgreSQL"
systemctl enable postgresql || print_error "Failed to enable PostgreSQL"

# Configure PostgreSQL for SonarQube
echo "Configuring PostgreSQL database..."
su - postgres -c "psql -c \"CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';\"" || {
    print_error "Failed to create database user"
}
su - postgres -c "psql -c \"CREATE DATABASE $DB_NAME OWNER $DB_USER;\"" || {
    print_error "Failed to create database"
}

# Create SonarQube user
echo "Creating SonarQube system user..."
useradd -r -s /bin/nologin "$SONAR_USER" || {
    print_error "Failed to create SonarQube user"
}

# Download and install SonarQube
echo "Downloading SonarQube $SONAR_VERSION..."
wget -q "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-$SONAR_VERSION.zip" \
    -O sonarqube.zip || {
    print_error "Failed to download SonarQube"
}

echo "Installing SonarQube..."
unzip -q sonarqube.zip -d /opt/ || print_error "Failed to unzip SonarQube"
mv "/opt/sonarqube-$SONAR_VERSION" "$SONAR_HOME"
chown -R "$SONAR_USER":"$SONAR_USER" "$SONAR_HOME"
chmod -R 750 "$SONAR_HOME"

# Configure SonarQube
echo "Configuring SonarQube..."
cat > "$SONAR_HOME/conf/sonar.properties" << EOF
sonar.jdbc.username=$DB_USER
sonar.jdbc.password=$DB_PASS
sonar.jdbc.url=jdbc:postgresql://localhost:5432/$DB_NAME
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.search.javaOpts=-Xmx512m -Xms512m
EOF

# Create systemd service file
echo "Creating SonarQube service..."
cat > /etc/systemd/system/sonarqube.service << EOF
[Unit]
Description=SonarQube service
After=network.target postgresql.service

[Service]
Type=forking
ExecStart=$SONAR_HOME/bin/linux-x86-64/sonar.sh start
ExecStop=$SONAR_HOME/bin/linux-x86-64/sonar.sh stop
User=$SONAR_USER
Group=$SONAR_USER
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start sonarqube || print_error "Failed to start SonarQube"
systemctl enable sonarqube || print_error "Failed to enable SonarQube"

# Configure firewall (if active)
if systemctl is-active firewalld >/dev/null 2>&1; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port=9000/tcp || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Wait for SonarQube to start (up to 60 seconds)
echo "Waiting for SonarQube to initialize..."
timeout 60s bash -c "until curl -s http://localhost:9000 >/dev/null; do sleep 2; done" || {
    print_error "SonarQube failed to start within 60 seconds"
}

print_success "SonarQube installation completed successfully!"
echo "------------------------------------------------"
echo "Access SonarQube at: http://<server-ip>:9000"
echo "Default credentials: admin/admin"
echo "Change the admin password after first login!"
echo "Database: PostgreSQL, DB: $DB_NAME, User: $DB_USER"
echo "------------------------------------------------"

exit $SUCCESS
