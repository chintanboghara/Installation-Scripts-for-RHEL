#!/bin/bash

# Script to install Apache Tomcat on RHEL (versions 7, 8, 9)
# Must be run with root privileges

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
TOMCAT_VERSION="10.1.20"  # Latest Tomcat 10 version as of March 2025
TOMCAT_USER="tomcat"
TOMCAT_HOME="/opt/tomcat"
TOMCAT_PORT=8080

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

# Install required dependencies (Java is required for Tomcat)
echo "Installing dependencies..."
yum install -y java-17-openjdk wget tar || print_error "Failed to install dependencies"

# Verify Java installation
if command -v java &>/dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    print_success "Java installed: $JAVA_VERSION"
else
    print_error "Java installation failed"
fi

# Create Tomcat user
echo "Creating Tomcat user..."
useradd -r -m -U -d "$TOMCAT_HOME" -s /bin/nologin "$TOMCAT_USER" || {
    print_error "Failed to create Tomcat user"
}

# Download Tomcat
echo "Downloading Apache Tomcat $TOMCAT_VERSION..."
wget -q "https://downloads.apache.org/tomcat/tomcat-10/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" \
    -O tomcat.tar.gz || {
    print_error "Failed to download Tomcat"
}

# Extract and install Tomcat
echo "Installing Tomcat..."
tar xzf tomcat.tar.gz -C "$TOMCAT_HOME" --strip-components=1 || print_error "Failed to extract Tomcat"
rm -f tomcat.tar.gz

# Set permissions
chown -R "$TOMCAT_USER":"$TOMCAT_USER" "$TOMCAT_HOME"
chmod -R 750 "$TOMCAT_HOME"

# Configure Tomcat port (optional)
echo "Configuring Tomcat to listen on port $TOMCAT_PORT..."
sed -i "s/8080/$TOMCAT_PORT/" "$TOMCAT_HOME/conf/server.xml" || {
    echo "Warning: Failed to update Tomcat port; default port 8080 will be used"
}

# Create systemd service file
echo "Creating Tomcat systemd service..."
cat > /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking
User=$TOMCAT_USER
Group=$TOMCAT_USER
Environment="JAVA_HOME=/usr/lib/jvm/jre"
Environment="CATALINA_PID=$TOMCAT_HOME/temp/tomcat.pid"
Environment="CATALINA_HOME=$TOMCAT_HOME"
Environment="CATALINA_BASE=$TOMCAT_HOME"
ExecStart=$TOMCAT_HOME/bin/startup.sh
ExecStop=$TOMCAT_HOME/bin/shutdown.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start Tomcat
systemctl daemon-reload || print_error "Failed to reload systemd"
systemctl start tomcat || print_error "Failed to start Tomcat"
systemctl enable tomcat || print_error "Failed to enable Tomcat"

# Configure firewall (if active)
if systemctl is-active firewalld &>/dev/null; then
    echo "Configuring firewall..."
    firewall-cmd --permanent --add-port="$TOMCAT_PORT/tcp" || {
        echo "Warning: Failed to configure firewall"
    }
    firewall-cmd --reload || {
        echo "Warning: Failed to reload firewall rules"
    }
fi

# Wait for Tomcat to start (up to 30 seconds)
echo "Waiting for Tomcat to start..."
timeout 30s bash -c "until curl -s http://localhost:$TOMCAT_PORT >/dev/null; do sleep 1; done" || {
    print_error "Tomcat failed to start within 30 seconds"
}

# Verify Tomcat installation
if systemctl is-active tomcat &>/dev/null; then
    print_success "Tomcat installed and running successfully"
else
    print_error "Tomcat verification failed"
fi

# Final success message and usage instructions
print_success "Tomcat installation completed successfully!"
echo "------------------------------------------------"
echo "Tomcat version: $TOMCAT_VERSION"
echo "Access Tomcat at: http://<server-ip>:$TOMCAT_PORT"
echo "Tomcat home: $TOMCAT_HOME"
echo "Service: systemctl {start|stop|restart} tomcat"
echo "Default credentials for manager app: configure in $TOMCAT_HOME/conf/tomcat-users.xml"
echo "Documentation: https://tomcat.apache.org/tomcat-10.1-doc/"
echo "------------------------------------------------"

exit $SUCCESS
