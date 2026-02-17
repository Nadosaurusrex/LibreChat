# {{INSTANCE_NAME}} Instance

## Setup

1. Copy `.env.example` to `.env` and fill in the real values:
   ```bash
   cp .env.example .env
   ```

2. Generate secrets:
   ```bash
   ../../scripts/generate-secrets.sh
   ```

3. Edit `librechat.yaml` with your system prompt and configuration.

4. Start services:
   ```bash
   docker compose --project-directory . -f ../../shared/docker-compose.base.yml -f docker-compose.yml up -d
   ```

5. Check status:
   ```bash
   docker compose --project-directory . -f ../../shared/docker-compose.base.yml -f docker-compose.yml ps
   ```

## Ports

- LibreChat: `{{LIBRECHAT_PORT}}`
- LiteLLM: `{{LITELLM_PORT}}`

## Logs

```bash
docker compose --project-directory . -f ../../shared/docker-compose.base.yml -f docker-compose.yml logs -f librechat
```
