#!/bin/bash
set -e

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
  echo "Please don't run as root"
  exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p config/nginx/auth
mkdir -p mlflow/artifacts
mkdir -p mlflow/db

echo "📦 Installing dependencies..."
# Install required packages
sudo apt-get update
sudo apt-get install -y \
    apache2-utils \
    docker.io \
    docker-compose

# Set up docker permissions
echo "🐳 Setting up Docker permissions..."
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker

# Create auth file
echo "🔒 Setting up authentication..."
if [ ! -f config/nginx/auth/.htpasswd ]; then
    # Generate random password
    PASSWORD=$(openssl rand -base64 12)
    
    # Create htpasswd file
    htpasswd -bc config/nginx/auth/.htpasswd admin "$PASSWORD"
    
    echo "Basic auth credentials:"
    echo "Username: admin"
    echo "Password: $PASSWORD"
    echo "⚠️  Please save these credentials!"
fi

# Generate environment file
echo "⚙️  Generating environment file..."
if [ ! -f .env ]; then
    # Generate random string for agent secret
    AGENT_SECRET=$(openssl rand -hex 16)
    
    # Create .env file from template
    cp .env.example .env
    
    # Update agent secret
    sed -i "s/WOODPECKER_AGENT_SECRET=.*/WOODPECKER_AGENT_SECRET=$AGENT_SECRET/" .env
    
    echo "⚠️  Please update .env file with your GitHub OAuth credentials"
fi

echo "🚀 Starting services..."
# Ensure docker socket has correct permissions
sudo chmod 666 /var/run/docker.sock

# Start services
docker-compose -f services/docker-compose.yml up -d

# Show bore tunnel URL
echo "🌍 Waiting for Bore tunnel..."
sleep 5
BORE_URL=$(docker logs bore-tunnel 2>&1 | grep "bore.pub" | head -n 1)
echo "Bore tunnel URL: $BORE_URL"

echo """
✅ Setup complete! 

Next steps:
1. Update your .env file with:
   - GitHub OAuth credentials
   - Bore tunnel URL shown above

2. Restart services after updating .env:
   docker-compose -f services/docker-compose.yml restart

3. Log out and log back in for Docker permissions to take effect

Need to see the basic auth credentials again?
Run: scripts/setup_auth.sh
"""

# Check if reboot is needed for group changes
if ! groups $USER | grep -q docker; then
    echo "⚠️  Please log out and log back in for Docker group changes to take effect"
fi