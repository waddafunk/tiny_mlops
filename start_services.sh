#!/bin/bash
set -e

# Function to get bore URL from logs
get_bore_url() {
    local max_attempts=10
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        local url=$(docker logs bore-tunnel 2>&1 | grep "listening at bore.pub:" | tail -n 1 | awk '{print $NF}' | cut -d':' -f2)
        if [ ! -z "$url" ]; then
            echo "$url"
            return 0
        fi
        echo "Attempt $attempt: Waiting for bore tunnel URL..."
        sleep 2
        attempt=$((attempt + 1))
    done
    return 1
}

# Generate secrets
AGENT_SECRET=$(openssl rand -hex 16)
COOKIE_SECRET=$(openssl rand -hex 32)

# Stop all services
echo "Stopping existing services..."
(cd services && docker-compose down)

# Setup environment file if it doesn't exist
if [ ! -f "services/.env" ]; then
    echo "Creating initial .env file..."
    
    # Create services/.env file with all required variables
    cat > services/.env << EOF
WOODPECKER_OPEN=true
WOODPECKER_GITHUB=true
WOODPECKER_GITHUB_CLIENT=pending
WOODPECKER_GITHUB_SECRET=pending
WOODPECKER_ADMIN=pending
WOODPECKER_AGENT_SECRET=$AGENT_SECRET
WOODPECKER_HOST=http://pending.bore.pub

# Authentication settings
WOODPECKER_COOKIE_SECRET=$COOKIE_SECRET
WOODPECKER_COOKIE_SECURE=false
WOODPECKER_COOKIE_TIMEOUT=720h
WOODPECKER_SESSION_EXPIRES=720h

# Server settings
WOODPECKER_SERVER_PROXY=true
WOODPECKER_SERVER_ADDR=:8000
WOODPECKER_GRPC_ADDR=:9000

# Additional settings for OAuth
WOODPECKER_GITHUB_SKIP_VERIFY=false
WOODPECKER_GITHUB_URL=https://github.com
WOODPECKER_GITHUB_API=https://api.github.com
EOF
else
    # Update existing .env with new secrets
    sed -i "s/WOODPECKER_AGENT_SECRET=.*/WOODPECKER_AGENT_SECRET=$AGENT_SECRET/" services/.env
    sed -i "s/WOODPECKER_COOKIE_SECRET=.*/WOODPECKER_COOKIE_SECRET=$COOKIE_SECRET/" services/.env
fi

# Start only bore tunnel
echo "Starting bore tunnel..."
(cd services && docker-compose up -d bore-tunnel)

# Get the bore URL
echo "Waiting for bore tunnel URL..."
sleep 2  # Give bore a moment to start

BORE_PORT=$(get_bore_url)
if [ -z "$BORE_PORT" ]; then
    echo "Failed to get bore tunnel URL"
    exit 1
fi

BORE_URL="bore.pub:${BORE_PORT}"
echo "Detected bore URL: $BORE_URL"

# Update .env file with new URL
echo "Updating .env with bore URL: $BORE_URL"
sed -i "s#WOODPECKER_HOST=.*#WOODPECKER_HOST=http://$BORE_URL#" services/.env

# Display current env contents
echo "Current .env contents:"
cat services/.env

# Ask for GitHub configuration if not set
if grep -q "WOODPECKER_GITHUB_CLIENT=pending" services/.env; then
    echo """
Please enter your GitHub OAuth credentials:
(You can get these from https://github.com/settings/developers)
"""
    read -p "GitHub OAuth Client ID: " github_client
    read -p "GitHub OAuth Secret: " github_secret
    read -p "Your GitHub username: " github_username
    
    sed -i "s/WOODPECKER_GITHUB_CLIENT=.*/WOODPECKER_GITHUB_CLIENT=$github_client/" services/.env
    sed -i "s/WOODPECKER_GITHUB_SECRET=.*/WOODPECKER_GITHUB_SECRET=$github_secret/" services/.env
    sed -i "s/WOODPECKER_ADMIN=.*/WOODPECKER_ADMIN=$github_username/" services/.env
fi

# Start all remaining services
echo "Starting remaining services..."
(cd services && docker-compose up -d)

echo """
✅ Services started successfully!

Bore tunnel URL: http://$BORE_URL
You can now:
1. Access Woodpecker CI at http://$BORE_URL
2. Set up GitHub OAuth callback URL to http://$BORE_URL/authorize

Need to see the basic auth credentials?
Run: scripts/setup_auth.sh

Tailing logs in 3 seconds... (Ctrl+C to exit)
"""

sleep 3

# Tail the logs to check for any issues
(cd services && docker-compose logs -f)