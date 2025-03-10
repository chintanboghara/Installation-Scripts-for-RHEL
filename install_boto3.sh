#!/bin/bash

# Script to install Boto3 (AWS SDK for Python) on RHEL (versions 7, 8, 9)
# Must be run with root privileges for system-wide installation

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
PYTHON_VERSION="3"  # Default Python 3 version for the system

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
    print_error "This script must be run as root for system-wide installation"
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

# Install Python 3 and pip based on RHEL version
echo "Installing Python 3 and pip..."
if [ "$RHEL_VERSION" == "7" ]; then
    # RHEL 7 requires EPEL for Python 3.6
    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm || {
        print_error "Failed to install EPEL repository"
    }
    yum install -y python36 python36-pip || print_error "Failed to install Python 3.6 and pip"
    PYTHON_CMD="python3.6"
    PIP_CMD="pip3.6"
elif [ "$RHEL_VERSION" == "8" ] || [ "$RHEL_VERSION" == "9" ]; then
    yum install -y python3 python3-pip || print_error "Failed to install Python 3 and pip"
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
else
    print_error "Unsupported RHEL version: $RHEL_VERSION"
fi

# Verify Python installation
if command -v "$PYTHON_CMD" &>/dev/null; then
    PYTHON_VERSION_INSTALLED=$("$PYTHON_CMD" --version)
    print_success "Python installed: $PYTHON_VERSION_INSTALLED"
else
    print_error "Python installation failed"
fi

# Verify pip installation
if command -v "$PIP_CMD" &>/dev/null; then
    PIP_VERSION=$("$PIP_CMD" --version)
    print_success "pip installed: $PIP_VERSION"
else
    print_error "pip installation failed"
fi

# Upgrade pip to the latest version
echo "Upgrading pip..."
"$PIP_CMD" install --upgrade pip -q || print_error "Failed to upgrade pip"

# Install Boto3
echo "Installing Boto3..."
"$PIP_CMD" install boto3 -q || print_error "Failed to install Boto3"

# Verify Boto3 installation
echo "Verifying Boto3 installation..."
if "$PYTHON_CMD" -c "import boto3; print(boto3.__version__)" &>/dev/null; then
    BOTO3_VERSION=$("$PYTHON_CMD" -c "import boto3; print(boto3.__version__)")
    print_success "Boto3 installed: $BOTO3_VERSION"
else
    print_error "Boto3 installation verification failed"
fi

# Test Boto3 basic functionality
echo "Testing Boto3..."
cat > /tmp/boto3_test.py << EOF
import boto3
print("Boto3 is working correctly!")
EOF

"$PYTHON_CMD" /tmp/boto3_test.py | grep -q "Boto3 is working" || {
    print_error "Boto3 functionality test failed"
}
rm -f /tmp/boto3_test.py

# Final success message and usage instructions
print_success "Boto3 installation completed successfully!"
echo "------------------------------------------------"
echo "Python version: $PYTHON_VERSION_INSTALLED"
echo "pip version: $PIP_VERSION"
echo "Boto3 version: $BOTO3_VERSION"
echo "Use '$PYTHON_CMD' to run Python scripts"
echo "Configure AWS credentials: aws configure (requires AWS CLI)"
echo "Example Boto3 usage:"
echo "  import boto3"
echo "  s3 = boto3.client('s3')"
echo "  buckets = s3.list_buckets()"
echo "Documentation: https://boto3.amazonaws.com/v1/documentation/api/latest/index.html"
echo "------------------------------------------------"

exit $SUCCESS
