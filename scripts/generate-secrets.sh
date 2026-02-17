#!/usr/bin/env bash
set -euo pipefail

# Generate cryptographic secrets and update .env file in the current directory
# Usage: cd instances/<name> && ../../scripts/generate-secrets.sh

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
    if [ -f ".env.example" ]; then
        echo "==> No .env found, copying from .env.example..."
        cp .env.example "$ENV_FILE"
    else
        echo "Error: No .env or .env.example found in current directory"
        exit 1
    fi
fi

echo "==> Generating secrets..."

CREDS_KEY=$(openssl rand -hex 32)
CREDS_IV=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -hex 32)
JWT_REFRESH_SECRET=$(openssl rand -hex 32)
LITELLM_MASTER_KEY="sk-litellm-$(openssl rand -hex 12)"
MEILI_MASTER_KEY=$(openssl rand -hex 16)
POSTGRES_PASSWORD=$(openssl rand -hex 16)

# Replace CHANGE_ME placeholders in .env
sed -i '' "s/^CREDS_KEY=CHANGE_ME$/CREDS_KEY=${CREDS_KEY}/" "$ENV_FILE"
sed -i '' "s/^CREDS_IV=CHANGE_ME$/CREDS_IV=${CREDS_IV}/" "$ENV_FILE"
sed -i '' "s/^JWT_SECRET=CHANGE_ME$/JWT_SECRET=${JWT_SECRET}/" "$ENV_FILE"
sed -i '' "s/^JWT_REFRESH_SECRET=CHANGE_ME$/JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}/" "$ENV_FILE"
sed -i '' "s/^LITELLM_MASTER_KEY=CHANGE_ME$/LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}/" "$ENV_FILE"
sed -i '' "s/^MEILI_MASTER_KEY=CHANGE_ME$/MEILI_MASTER_KEY=${MEILI_MASTER_KEY}/" "$ENV_FILE"
sed -i '' "s/^POSTGRES_PASSWORD=CHANGE_ME$/POSTGRES_PASSWORD=${POSTGRES_PASSWORD}/" "$ENV_FILE"

echo "==> Secrets generated and written to ${ENV_FILE}"
echo "    CREDS_KEY, CREDS_IV, JWT_SECRET, JWT_REFRESH_SECRET,"
echo "    LITELLM_MASTER_KEY, MEILI_MASTER_KEY, POSTGRES_PASSWORD"
echo ""
echo "    You still need to set manually:"
echo "    - AWS_ACCESS_KEY_ID"
echo "    - AWS_SECRET_ACCESS_KEY"
