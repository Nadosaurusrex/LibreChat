#!/usr/bin/env bash
set -euo pipefail

# Scaffold a new instance from the _template
# Usage: ./scripts/new-instance.sh <client-name>
# Example: ./scripts/new-instance.sh insurance

CLIENT_NAME="${1:?Usage: new-instance.sh <client-name>}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="${REPO_ROOT}/instances/_template"
TARGET_DIR="${REPO_ROOT}/instances/${CLIENT_NAME}"

if [ -d "$TARGET_DIR" ]; then
    echo "Error: Instance '${CLIENT_NAME}' already exists at ${TARGET_DIR}"
    exit 1
fi

# Generate a slug from the client name (lowercase, hyphens for spaces)
INSTANCE_SLUG=$(echo "$CLIENT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

# Prompt for ports
read -rp "LibreChat port (e.g. 3082): " LIBRECHAT_PORT
read -rp "LiteLLM port (e.g. 4002): " LITELLM_PORT

# Display name (capitalize first letter)
INSTANCE_NAME="$(echo "${CLIENT_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${CLIENT_NAME:1}"

echo "==> Creating instance '${CLIENT_NAME}' from template..."

# Copy template
cp -r "$TEMPLATE_DIR" "$TARGET_DIR"

# Replace placeholders in all files
find "$TARGET_DIR" -type f | while read -r file; do
    sed -i '' \
        -e "s/{{INSTANCE_NAME}}/${INSTANCE_NAME}/g" \
        -e "s/{{INSTANCE_SLUG}}/${INSTANCE_SLUG}/g" \
        -e "s/{{LIBRECHAT_PORT}}/${LIBRECHAT_PORT}/g" \
        -e "s/{{LITELLM_PORT}}/${LITELLM_PORT}/g" \
        "$file"
done

# Copy .env.example to .env as starting point
cp "${TARGET_DIR}/.env.example" "${TARGET_DIR}/.env"

echo "==> Instance created at ${TARGET_DIR}"
echo ""
echo "Next steps:"
echo "  1. Edit ${TARGET_DIR}/.env with real secrets"
echo "     (or run: cd ${TARGET_DIR} && ../../scripts/generate-secrets.sh)"
echo "  2. Edit ${TARGET_DIR}/librechat.yaml (system prompt, greeting, etc.)"
echo "  3. Start: cd ${TARGET_DIR} && docker compose --project-directory . -f ../../shared/docker-compose.base.yml -f docker-compose.yml up -d"
