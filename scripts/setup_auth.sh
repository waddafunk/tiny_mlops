#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
AUTH_DIR="$PROJECT_ROOT/config/nginx/auth"
AUTH_FILE="$AUTH_DIR/.htpasswd"

# Check if htpasswd command is available
if ! command -v htpasswd >/dev/null 2>&1; then
    echo "Error: htpasswd command not found. Please install apache2-utils or httpd-tools." >&2
    exit 1
fi

echo "Creating directories..."
# Create directories with proper permissions
mkdir -p "$AUTH_DIR"
chmod 750 "$AUTH_DIR"  # More restrictive permissions

if [ ! -f "$AUTH_FILE" ]; then
    echo "Setting up basic auth..."
    
    # Generate random password with specific character set
    PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c 16)
    
    # Create htpasswd file with proper permissions
    echo "Creating htpasswd file..."
    install -m 640 /dev/null "$AUTH_FILE"  # Create with proper permissions
    
    # Create htpasswd file
    if ! htpasswd -bc "$AUTH_FILE" admin "$PASSWORD"; then
        echo "Error: Failed to create htpasswd file" >&2
        exit 1
    fi
    
    echo "Basic auth credentials:"
    echo "Username: admin"
    echo "Password: $PASSWORD"
    echo "Please save these credentials securely!"
    
    # Verify file was created and has correct permissions
    if [ ! -f "$AUTH_FILE" ]; then
        echo "Error: Failed to verify htpasswd file creation" >&2
        exit 1
    fi
    ls -la "$AUTH_FILE"
else
    echo "Auth file already exists."
    echo "Username: admin"
    echo "To manage credentials:"
    echo "1. Delete $AUTH_FILE and run this script again for a new random password"
    echo "2. Set a new password manually: htpasswd -b $AUTH_FILE admin NEW_PASSWORD"
    echo "3. View current users: cut -d: -f1 $AUTH_FILE"
fi