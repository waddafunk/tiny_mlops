#!/bin/bash
set -e

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install required packages
sudo apt-get install -y \
    apache2-utils \
    docker.io \
    docker-compose

# Add current user to docker group
sudo usermod -aG docker $USER

# Verify docker installation
docker --version
docker-compose --version