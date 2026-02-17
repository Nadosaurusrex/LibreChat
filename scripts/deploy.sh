#!/usr/bin/env bash
set -euo pipefail

# Deploy an instance to a remote machine via rsync + ssh
# Usage: ./scripts/deploy.sh <instance> <ssh-target>
# Example: ./scripts/deploy.sh lawyer root@192.168.1.100

INSTANCE="${1:?Usage: deploy.sh <instance> <ssh-target>}"
SSH_TARGET="${2:?Usage: deploy.sh <instance> <ssh-target>}"
REMOTE_DIR="/opt/librechat"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTANCE_DIR="${REPO_ROOT}/instances/${INSTANCE}"

if [ ! -d "$INSTANCE_DIR" ]; then
    echo "Error: Instance '${INSTANCE}' not found at ${INSTANCE_DIR}"
    exit 1
fi

if [ ! -f "${INSTANCE_DIR}/.env" ]; then
    echo "Error: .env file not found for instance '${INSTANCE}'"
    echo "Create it from .env.example first"
    exit 1
fi

echo "==> Deploying instance '${INSTANCE}' to ${SSH_TARGET}:${REMOTE_DIR}"

# Sync the repo (excluding .env files, .git, and node_modules)
echo "==> Syncing repository..."
rsync -avz --delete \
    --exclude '.git' \
    --exclude 'node_modules' \
    --exclude 'instances/*/.env' \
    --exclude '.claude' \
    "${REPO_ROOT}/" \
    "${SSH_TARGET}:${REMOTE_DIR}/"

# Sync the instance .env separately
echo "==> Syncing instance .env..."
rsync -avz \
    "${INSTANCE_DIR}/.env" \
    "${SSH_TARGET}:${REMOTE_DIR}/instances/${INSTANCE}/.env"

# SSH in and bring up services
echo "==> Starting services on remote..."
ssh "${SSH_TARGET}" bash -c "'
    cd ${REMOTE_DIR}/instances/${INSTANCE}
    docker compose --project-directory . -f ../../shared/docker-compose.base.yml -f docker-compose.yml pull
    docker compose --project-directory . -f ../../shared/docker-compose.base.yml -f docker-compose.yml up -d
'"

echo "==> Deploy complete for '${INSTANCE}' on ${SSH_TARGET}"
