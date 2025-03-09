#!/bin/bash

# Script to install Rust on RHEL (versions 7, 8, 9)
# Can be run as root or regular user (installs system-wide or user-specific)

# Exit codes
SUCCESS=0
ERROR=1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Configuration variables
RUSTUP_URL="https://sh.rustup.rs"

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
    echo "Running as root, installing Rust system-wide"
    INSTALL_DIR="/usr/local"
    PATH_UPDATE=""
else
    echo "Running as non-root user, installing Rust in home directory"
    INSTALL_DIR="$HOME/.rustup"
    PATH_UPDATE='export PATH="$HOME/.cargo/bin:$PATH"'
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
    yum install -y curl gcc || print_error "Failed to install dependencies"
else
    command -v curl &>/dev/null || print_error "curl is required but not installed"
    command -v gcc &>/dev/null || print_error "gcc is required but not installed"
fi

# Download and run rustup installer
echo "Downloading and installing rustup..."
if [ "$(id -u)" -eq 0 ]; then
    curl --proto '=https' --tlsv1.2 -sSf "$RUSTUP_URL" | sh -s -- -y --no-modify-path --default-toolchain stable || {
        print_error "Failed to install Rust via rustup"
    }
    # Move rustup installation to system-wide location
    mv "$HOME/.rustup" "$INSTALL_DIR/rustup"
    mv "$HOME/.cargo" "$INSTALL_DIR/cargo"
    chown -R root:root "$INSTALL_DIR/rustup" "$INSTALL_DIR/cargo"
    ln -sf "$INSTALL_DIR/cargo/bin/rustc" /usr/local/bin/rustc
    ln -sf "$INSTALL_DIR/cargo/bin/cargo" /usr/local/bin/cargo
else
    curl --proto '=https' --tlsv1.2 -sSf "$RUSTUP_URL" | sh -s -- -y || {
        print_error "Failed to install Rust via rustup"
    }
    # Update PATH in .bashrc for non-root user
    if ! grep -q "$HOME/.cargo/bin" "$HOME/.bashrc"; then
        echo "$PATH_UPDATE" >> "$HOME/.bashrc"
    fi
fi

# Source cargo environment (for current session)
if [ "$(id -u)" -eq 0 ]; then
    source "$INSTALL_DIR/cargo/env" 2>/dev/null || true
else
    source "$HOME/.cargo/env" 2>/dev/null || true
fi

# Verify Rust installation
echo "Verifying Rust installation..."
if command -v rustc &>/dev/null; then
    RUST_VERSION=$(rustc --version)
    print_success "Rust installed: $RUST_VERSION"
else
    print_error "Rust installation failed"
fi

# Verify Cargo installation
if command -v cargo &>/dev/null; then
    CARGO_VERSION=$(cargo --version)
    print_success "Cargo installed: $CARGO_VERSION"
else
    print_error "Cargo installation failed"
fi

# Test Rust functionality
echo "Testing Rust..."
echo 'fn main() { println!("Hello from Rust!"); }' > test.rs
rustc test.rs && ./test | grep -q "Hello from Rust" || {
    print_error "Rust functionality test failed"
}
rm -f test.rs test

# Final success message and usage instructions
print_success "Rust and Cargo installation completed successfully!"
echo "------------------------------------------------"
if [ "$(id -u)" -eq 0 ]; then
    echo "Rust installed system-wide at: $INSTALL_DIR/rustup"
    echo "Cargo installed at: $INSTALL_DIR/cargo"
    echo "Executables: /usr/local/bin/rustc, /usr/local/bin/cargo"
else
    echo "Rust installed at: $HOME/.rustup"
    echo "Cargo installed at: $HOME/.cargo"
    echo "Run 'source ~/.bashrc' or log out/in to update PATH"
fi
echo "Use 'rustc' to compile Rust code"
echo "Use 'cargo' to manage Rust projects"
echo "Example: cargo new my_project"
echo "Update Rust: rustup update"
echo "Documentation: https://www.rust-lang.org/learn"
echo "------------------------------------------------"

exit $SUCCESS
