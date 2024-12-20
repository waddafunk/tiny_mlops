#!/bin/bash
set -e

# Function to get bore URL from logs
get_bore_url() {
    local max_attempts=15 # Increased max attempts
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        local url
        url=$(docker logs bore-tunnel 2>&1 | grep "listening at bore.pub:" | tail -n 1 | awk '{print $NF}' | cut -d':' -f2)
        if [ -n "$url" ]; then
            echo "$url"
            return 0
        fi
        echo "Attempt $attempt: Waiting for bore tunnel URL..."
        sleep 3 # Increased sleep time
        attempt=$((attempt + 1))
    done
    return 1
}

# Function to wait for service health
wait_for_service() {
    local service=$1
    local max_attempts=20
    local attempt=1

    echo "Waiting for $service to be healthy..."
    while [ $attempt -le $max_attempts ]; do
        if docker-compose -f "$SERVICES_DIR/docker-compose.yml" ps | grep "$service" | grep -q "Up"; then
            echo "$service is up!"
            return 0
        fi
        echo "Attempt $attempt: $service not yet healthy..."
        sleep 3
        attempt=$((attempt + 1))
    done
    echo "Error: $service failed to become healthy"
    return 1
}

# Get the absolute path to the services directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$SCRIPT_DIR/services"
ENV_FILE="$SERVICES_DIR/.env"

# Generate secrets
AGENT_SECRET=$(openssl rand -hex 16)
COOKIE_SECRET=$(openssl rand -hex 32)

# Stop all services
echo "Stopping existing services..."
(cd "$SERVICES_DIR" && docker-compose down -v)

# Setup environment file if it doesn't exist
if [ ! -f "$ENV_FILE" ]; then
    echo "Creating initial .env file..."

    # Create .env file with all required variables
    cat >"$ENV_FILE" <<EOF
WOODPECKER_OPEN=true
WOODPECKER_GITHUB=true
WOODPECKER_GITHUB_CLIENT=pending
WOODPECKER_GITHUB_SECRET=pending
WOODPECKER_ADMIN=pending
WOODPECKER_AGENT_SECRET=$AGENT_SECRET
WOODPECKER_HOST=http://pending.bore.pub
WOODPECKER_GITHUB_SCOPE=repo,repo:status,user:email,read:org

# Authentication settings
WOODPECKER_COOKIE_SECRET=$COOKIE_SECRET
WOODPECKER_COOKIE_SECURE=false
WOODPECKER_COOKIE_TIMEOUT=720h
WOODPECKER_SESSION_EXPIRES=720h

# Server settings
WOODPECKER_SERVER_PROXY=true
WOODPECKER_SERVER_ADDR=:8000
WOODPECKER_GRPC_ADDR=:9000
WOODPECKER_GRPC_SECURE=false
WOODPECKER_MAX_WORKFLOWS=1

# Logs and debug
WOODPECKER_LOG_LEVEL=debug
EOF
else
    # Update existing .env with new secrets
    sed -i "s/WOODPECKER_AGENT_SECRET=.*/WOODPECKER_AGENT_SECRET=$AGENT_SECRET/" "$ENV_FILE"
    sed -i "s/WOODPECKER_COOKIE_SECRET=.*/WOODPECKER_COOKIE_SECRET=$COOKIE_SECRET/" "$ENV_FILE"
fi

# Start services in order
echo "Starting bore tunnel..."
(cd "$SERVICES_DIR" && docker-compose up -d bore-tunnel)

# Get the bore URL
echo "Waiting for bore tunnel URL..."
sleep 3 # Give bore a moment to start

BORE_PORT=$(get_bore_url)
if [ -z "$BORE_PORT" ]; then
    echo "Failed to get bore tunnel URL"
    exit 1
fi

BORE_URL="bore.pub:${BORE_PORT}"
echo "Detected bore URL: $BORE_URL"

# Update .env file with new URL
echo "Updating .env with bore URL: $BORE_URL"
sed -i "s#WOODPECKER_HOST=.*#WOODPECKER_HOST=http://$BORE_URL#" "$ENV_FILE"

# Ask for GitHub configuration if not set
if grep -q "WOODPECKER_GITHUB_CLIENT=pending" "$ENV_FILE"; then
    echo """
Please enter your GitHub OAuth credentials:
(You can get these from https://github.com/settings/developers)
"""
    read -rp "GitHub OAuth Client ID: " github_client
    read -rp "GitHub OAuth Secret: " github_secret
    read -rp "Your GitHub username: " github_username

    sed -i "s/WOODPECKER_GITHUB_CLIENT=.*/WOODPECKER_GITHUB_CLIENT=$github_client/" "$ENV_FILE"
    sed -i "s/WOODPECKER_GITHUB_SECRET=.*/WOODPECKER_GITHUB_SECRET=$github_secret/" "$ENV_FILE"
    sed -i "s/WOODPECKER_ADMIN=.*/WOODPECKER_ADMIN=$github_username/" "$ENV_FILE"
fi

# Start woodpecker server first and wait for it
echo "Starting Woodpecker server..."
(cd "$SERVICES_DIR" && docker-compose up -d woodpecker-server)
wait_for_service "woodpecker-server"

# Start woodpecker agent and wait for it
echo "Starting Woodpecker agent..."
(cd "$SERVICES_DIR" && docker-compose up -d woodpecker-agent)
wait_for_service "woodpecker-agent"

# Start remaining services
echo "Starting remaining services..."
(cd "$SERVICES_DIR" && docker-compose up -d nginx mlflow)

echo """
✅ Services started successfully!

Checking service status:
"""

# Show service status
(cd "$SERVICES_DIR" && docker-compose ps)

echo """

Bore tunnel URL: http://$BORE_URL

Important next steps:
1. Access Woodpecker CI at http://$BORE_URL
2. Update your GitHub OAuth app settings:
   - Homepage URL: http://$BORE_URL
   - Authorization callback URL: http://$BORE_URL/authorize

Need to see the basic auth credentials?
Run: scripts/setup_auth.sh

Tailing logs in 5 seconds... (Ctrl+C to exit)
"""

sleep 5

# Tail the logs to check for any issues
(cd "$SERVICES_DIR" && docker-compose logs -f)
