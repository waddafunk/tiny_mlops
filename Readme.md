# Raspberry Pi MLOps Server

This repository contains a complete setup for running Woodpecker CI, MLflow, and related services on a Raspberry Pi.

## Prerequisites

- Raspberry Pi 3 or newer
- Fresh install of Raspberry Pi OS (64-bit recommended)
- Internet connection
- GitHub account

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/waddafunk/tiny_mlops.git
   cd tiny_mlops
   ```

2. Run the installation script:
   ```bash
   chmod +x *.sh
   ./install.sh
   ```

3. Set up GitHub OAuth:
   - Go to GitHub Settings > Developer Settings > OAuth Apps
   - Create a new OAuth app
   - Set homepage URL to your Bore tunnel URL
   - Set callback URL to `your-bore-url/authorize`
   - Copy Client ID and Secret

4. Update .env file with your GitHub OAuth credentials

5. Restart services:
   ```bash
   docker-compose -f services/docker-compose.yml restart
   ```

## Services

- Woodpecker CI: CI/CD server (port 8000)
- MLflow: ML experiment tracking (port 5000)
- Nginx: Reverse proxy with basic auth
- Bore: Secure tunnel for GitHub webhooks

## Configuration

### Basic Auth
Default credentials are generated during installation. You can update them:
```bash
scripts/setup_auth.sh
```

### Environment Variables
Copy `.env.example` to `.env` and update:
- WOODPECKER_HOST: Your Bore tunnel URL
- WOODPECKER_GITHUB_CLIENT: GitHub OAuth client ID
- WOODPECKER_GITHUB_SECRET: GitHub OAuth client secret
- WOODPECKER_ADMIN: Your GitHub username

## Maintenance

- View logs: `docker-compose -f services/docker-compose.yml logs`
- Restart services: `docker-compose -f services/docker-compose.yml restart`
- Update services: `docker-compose -f services/docker-compose.yml pull`

## Security Notes

- Basic auth protects all routes except webhooks
- All services auto-restart on failure
- MLflow is accessible only locally by default