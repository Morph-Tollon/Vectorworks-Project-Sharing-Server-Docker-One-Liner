#!/bin/bash

## Check if docker is installed from the correct source (i.e., not the default repo) and that docker compose is available. If not, provide instructions to install it.

if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker from https://docs.docker.com/engine/install/ubuntu/ and try again."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "Docker Compose is not installed. Please install it from https://docs.docker.com/engine/install/ubuntu/ and try again."
    exit 1
fi




## Flash up a screen to allow the user to select the version they desire
## Wrapped in an 'if' statement to gracefully exit if the user hits "Cancel"
if ! CHOICE=$(whiptail --title "Edition Selection" \
                 --default-item "2026" \
                 --menu "Choose an edition from below:" 15 50 3 \
                 "2024" "" \
                 "2025" "" \
                 "2026" "" \
                 3>&1 1>&2 2>&3); then
    echo "Installation cancelled by user."
    exit 1
fi

echo "You selected: Vectorworks $CHOICE"

## Create a temp directory first
mkdir -p /tmp/vectorworks_pss

## Added -L to follow redirects and -f to fail silently on server errors (e.g., 404s)
echo "Downloading Vectorworks Project Sharing Server..."
curl -f -L -o /tmp/vectorworks_pss.zip "https://release.vectorworks.net/latest/Vectorworks/$CHOICE-NNA-eng-pss"

echo "Extracting primary package..."
unzip -q -o /tmp/vectorworks_pss.zip -d /tmp/vectorworks_pss

cd /tmp/vectorworks_pss

## Look for inner zip files recursively. Mac packages often nest files deeply 
## inside .app bundles (e.g., Contents/Resources/...).
echo "Searching for the inner Docker image zip..."
find . -type f -name "*.zip" | while read -r file; do
    echo "Unzipping nested package: $file..."
    unzip -q -o "$file" -d /tmp/vectorworks_pss/image
done

## Safely locate the .tar file regardless of how the inner zip structured its folders
echo "Locating the Docker image tarball..."
TAR_PATH=$(find /tmp/vectorworks_pss/image -type f -name "project-sharing-server.tar" | head -n 1)

if [ -z "$TAR_PATH" ]; then
    echo "Error: project-sharing-server.tar not found. The download or extraction failed."
    exit 1
fi

echo "Loading image into local Docker registry..."
docker load -i "$TAR_PATH"

## Create a docker-compose.yml file.
## IMPORTANT: Using <<'EOL' (with quotes) prevents Bash from replacing your 
## ${PROJECTS_PATH} variables with empty strings before writing the file.
echo "Generating docker-compose.yml..."
cat <<'EOL' > ~/docker-compose.yml
services:
  vectorworks_project_server:
    image: project-sharing-server:latest
    container_name: project-sharing-server
    restart: unless-stopped
    ports:
      - "22001:22001"
    volumes:
      - ${PROJECTS_PATH}:/usr/psserverd/Projects
      - ${LOGS_PATH}:/usr/psserverd/log
EOL

## Create a .env file.
## Using <<EOL (without quotes) here so Bash evaluates ${HOME} into an absolute path.
echo "Generating .env file..."
cat <<EOL > ~/.env
PROJECTS_PATH=${HOME}/vectorworks_projects
LOGS_PATH=${HOME}/vectorworks_logs
EOL

## Pre-create the host directories so Docker doesn't create them as the 'root' user
mkdir -p "${HOME}/vectorworks_projects"
mkdir -p "${HOME}/vectorworks_logs"

## Clean up the temporary files
echo "Cleaning up..."
rm -rf /tmp/vectorworks_pss.zip
rm -rf /tmp/vectorworks_pss

echo "Installation complete! Start the container now? [Y/n]"
read -r START_CHOICE
if [[ "$START_CHOICE" =~ ^[Yy]$ || -z "$START_CHOICE" ]]; then
    echo "Starting the Vectorworks Project Sharing Server container..."
    docker compose -f ~/docker-compose.yml up -d
    ## Get IP address of the host machine to display to the user
    HOST_IP=$(hostname -I | awk '{print $1}')
    echo "Container started. Access it at http://$HOST_IP:22001 within vectorworks."
else
    echo "You can start the container later by running: docker compose -f ~/docker-compose.yml up -d"
fi
