.PHONY: all install 

all: install 


install: 
	@echo "Installing..."
	mkdir -p ~/mlflow/artifacts
	mkdir -p ~/mlflow/db
