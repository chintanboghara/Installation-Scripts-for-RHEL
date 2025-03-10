#!/bin/bash

# Script to install Apache Maven on RHEL (versions 7, 8, 9)
# Can be run as root (system-wide) or regular user (user-specific)

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
MAVEN_VERSION="3.9.6"  # Latest Maven version as of March 2025
JAVA_VERSION="17"      # OpenJDK version compatible with Maven 3.9.x
MAVEN_HOME="/opt/maven"

# Function to print error messages and exit
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit $ERROR
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}$1${NC}"
}

# Determine if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "Running as root, installing Maven system-wide"
    INSTALL_DIR="$MAVEN_HOME"
    BIN_DIR="/usr/local/bin"
else
    echo "Running as non-root user, installing Maven in home directory"
    INSTALL_DIR="$HOME/.maven"
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
fi

# Check RHEL version
if [ -f /etc/redhat-release ]; then
    RHEL_VERSION=$(cat /etc/redhat-release | grep -oP ' release \K\d+')
else
    print_error "This script is designed for RHEL systems only"
fi

echo "Detected RHEL version: $RHEL_VERSION"

# Update system packages (if root)
echo "Updating system packages..."
if [ "$(id -u)" -eq 0 ]; then
    yum update -y || print_error "Failed to update system packages"
else
    echo "Skipping system update (requires root privileges)"
fi

# Install required dependencies
echo "Installing dependencies..."
if [ "$(id -u)" -eq 0 ]; then
    yum install -y java-"$JAVA_VERSION"-openjdk wget tar || {
        print_error "Failed to install dependencies"
    }
else
    command -v java &>/dev/null || print_error "Java is required but not installed (install java-$JAVA_VERSION-openjdk)"
    command -v wget &>/dev/null || print_error "wget is required but not installed"
    command -v tar &>/dev/null || print_error "tar is required but not installed"
fi

# Verify Java installation
if command -v java &>/dev/null; then
    JAVA_VERSION_INSTALLED=$(java -version 2>&1 | head -n 1)
    print_success "Java installed: $JAVA_VERSION_INSTALLED"
else
    print_error "Java installation failed or not found"
fi

# Set JAVA_HOME (if not already set)
if [ -z "$JAVA_HOME" ]; then
    JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
    if [ "$(id -u)" -eq 0 ]; then
        echo "export JAVA_HOME=$JAVA_HOME" >> /etc/environment
        source /etc/environment
    else
        echo "export JAVA_HOME=$JAVA_HOME" >> "$HOME/.bashrc"
    fi
    echo "JAVA_HOME set to: $JAVA_HOME"
fi

# Download Maven
echo "Downloading Apache Maven $MAVEN_VERSION..."
wget -q "https://downloads.apache.org/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz" \
    -O maven.tar.gz || {
    print_error "Failed to download Maven"
}

# Install Maven
echo "Installing Maven..."
mkdir -p "$INSTALL_DIR"
tar xzf maven.tar.gz -C "$INSTALL_DIR" --strip-components=1 || print_error "Failed to extract Maven"
rm -f maven.tar.gz

# Set permissions (root install only)
if [ "$(id -u)" -eq 0 ]; then
    chown -R root:root "$INSTALL_DIR"
    chmod -R 755 "$INSTALL_DIR"
fi

# Create symbolic link or update PATH
if [ "$(id -u)" -eq 0 ]; then
    ln -sf "$INSTALL_DIR/bin/mvn" "$BIN_DIR/mvn" || print_error "Failed to create Maven symlink"
else
    if ! grep -q "$BIN_DIR" "$HOME/.bashrc"; then
        echo "export PATH=\$PATH:$BIN_DIR" >> "$HOME/.bashrc"
    fi
    ln -sf "$INSTALL_DIR/bin/mvn" "$BIN_DIR/mvn" || print_error "Failed to create Maven symlink"
fi

# Source environment for current session
if [ "$(id -u)" -ne 0 ]; then
    source "$HOME/.bashrc"
fi

# Verify Maven installation
echo "Verifying Maven installation..."
if command -v mvn &>/dev/null; then
    MAVEN_VERSION_INSTALLED=$(mvn --version | grep -oP 'Apache Maven \K[0-9.]+')
    print_success "Maven installed: $MAVEN_VERSION_INSTALLED"
else
    print_error "Maven installation failed"
fi

# Test Maven functionality
echo "Testing Maven..."
mvn --version &>/dev/null || print_error "Maven functionality test failed"

# Final success message and usage instructions
print_success "Maven installation completed successfully!"
echo "------------------------------------------------"
echo "Maven version: $MAVEN_VERSION_INSTALLED"
echo "Java version: $JAVA_VERSION_INSTALLED"
if [ "$(id -u)" -eq 0 ]; then
    echo "Maven installed system-wide at: $INSTALL_DIR"
    echo "Executable: $BIN_DIR/mvn"
else
    echo "Maven installed at: $INSTALL_DIR"
    echo "Executable: $BIN_DIR/mvn"
    echo "Run 'source ~/.bashrc' or log out/in to update PATH"
fi
echo "Use 'mvn' to run Maven commands"
echo "Example: mvn clean install"
echo "Documentation: https://maven.apache.org/guides/"
echo "------------------------------------------------"

exit $SUCCESS
