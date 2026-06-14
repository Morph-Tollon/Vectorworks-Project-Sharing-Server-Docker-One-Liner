#!/bin/bash
set -euo pipefail

INSTALL_DIR="${HOME}/vectorworks-pss"
PROJECTS_DIR="${INSTALL_DIR}/projects"
LOGS_DIR="${INSTALL_DIR}/logs"
COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yml"
ENV_FILE="${INSTALL_DIR}/.env"
TMP_DIR="/tmp/vectorworks_pss"

echo "Checking dependencies..."

if ! command -v docker &>/dev/null; then
    echo "Docker is not installed."
    exit 1
fi

if ! docker compose version &>/dev/null; then
    echo "Docker Compose v2 plugin is not installed."
    exit 1
fi

if ! command -v whiptail &>/dev/null; then
    echo "whiptail is required."
    exit 1
fi

if ! CHOICE=$(whiptail --title "Vectorworks Edition" \
    --default-item "2026" \
    --menu "Choose version:" 15 50 3 \
    "2024" "" \
    "2025" "" \
    "2026" "" \
    3>&1 1>&2 2>&3); then
    echo "Cancelled."
    exit 1
fi

echo "Selected: Vectorworks ${CHOICE}"

rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}" "${INSTALL_DIR}" "${PROJECTS_DIR}" "${LOGS_DIR}"

echo "Downloading installer..."

curl -fL \
  -o "${TMP_DIR}/vectorworks_pss.zip" \
  "https://release.vectorworks.net/latest/Vectorworks/${CHOICE}-NNA-eng-pss"

echo "Extracting..."

unzip -q -o "${TMP_DIR}/vectorworks_pss.zip" -d "${TMP_DIR}"

find "${TMP_DIR}" -type f -name "*.zip" -exec unzip -q -o {} -d "${TMP_DIR}/image" \;

TAR_PATH=$(find "${TMP_DIR}/image" -type f -name "project-sharing-server.tar" | head -n 1)

if [[ -z "${TAR_PATH}" ]]; then
    echo "ERROR: Docker image not found."
    exit 1
fi

echo "Loading Docker image..."
docker load -i "${TAR_PATH}"

cat > "${COMPOSE_FILE}" <<EOF
services:
  vectorworks_project_server:
    image: project-sharing-server:latest
    container_name: project-sharing-server
    restart: unless-stopped
    ports:
      - "22001:22001"
    volumes:
      - ${PROJECTS_DIR}:/usr/psserverd/Projects
      - ${LOGS_DIR}:/usr/psserverd/Logs
EOF

cat > "${ENV_FILE}" <<EOF
PROJECTS_PATH=${PROJECTS_DIR}
LOGS_PATH=${LOGS_DIR}
EOF

rm -rf "${TMP_DIR}" "${TMP_DIR}.zip" 2>/dev/null || true

echo ""
read -rp "Start server now? [Y/n]: " START_CHOICE
START_CHOICE="${START_CHOICE:-Y}"

if [[ "${START_CHOICE}" =~ ^[Yy]$ ]]; then
    cd "${INSTALL_DIR}" || exit 1

    docker compose \
        --env-file "${ENV_FILE}" \
        -f "${COMPOSE_FILE}" \
        --project-directory "${INSTALL_DIR}" \
        up -d

    HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')

    echo "Started the PSS, connect from vectorworks on http://${HOST_IP}:22001"
else
    echo "Start with: cd ${INSTALL_DIR} && docker compose up -d"
fi
