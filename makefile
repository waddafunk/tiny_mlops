# Define phony targets (targets that don't create files)
.PHONY: all install format lint

# Default target that runs all tasks
all: install format lint

# Install required dependencies and create necessary directories
install:
	@echo "Installing..."
	mkdir -p ~/mlflow/artifacts
	mkdir -p ~/mlflow/db
	apt-get install -y curl shellcheck yamllint docker-compose wget
	# Download shfmt and make it executable
	wget https://github.com/mvdan/sh/releases/download/v3.7.0/shfmt_v3.7.0_linux_arm64 -O /usr/local/bin/shfmt
	chmod +x /usr/local/bin/shfmt

# Format shell scripts using shfmt
format:
	@echo "Formatting shell scripts..."
	shfmt -l -w -i 4 *.sh

# Lint shell scripts and YAML files
lint:
	@echo "Checking shell scripts..."
	shellcheck *.sh
	
	@echo "Checking YAML files..."
	find . -name "*.yml" -o -name "*.yaml" -exec yamllint -f parsable {} \;
	
	@echo "Validating docker-compose..."
	docker-compose -f services/docker-compose.yml config