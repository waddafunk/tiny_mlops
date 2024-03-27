FROM python:3.8-slim

# Set the working directory in the container
WORKDIR /usr/src/app

# Create a virtual environment and activate it
RUN python3 -m venv venv
ENV PATH="/usr/src/app/venv/bin:$PATH"

# Install any needed packages specified in requirements.txt
RUN pip install --upgrade pip
RUN pip install mlflow

# Set the working directory
WORKDIR /mlflow

# Expose the MLflow server port
EXPOSE 5000

# Set the entrypoint to run the MLflow server
ENTRYPOINT ["mlflow", "server"]
CMD ["--host", "0.0.0.0"]


