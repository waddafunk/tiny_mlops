#!/bin/bash
set -e

if [ ! -f .env ]; then
    echo "Generating .env file..."
    
    # Generate random string for agent secret
    AGENT_SECRET=$(openssl rand -hex 16)
    
    # Create .env file from template
    cp .env.example .env
    
    # Update agent secret
    sed -i "s/WOODPECKER_AGENT_SECRET=.*/WOODPECKER_AGENT_SECRET=$AGENT_SECRET/" .env
    
    echo "Please update .env file with your GitHub OAuth credentials"
else
    echo ".env file already exists"
fi