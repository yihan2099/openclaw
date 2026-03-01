#!/bin/bash
# Reproduce the local OpenClaw Docker setup
# Run from ~/dev/openclaw/ after cloning:
#   git clone https://github.com/openclaw/openclaw.git ~/dev/openclaw
set -euo pipefail

cd "$(dirname "$0")"

# 1. Build the image
docker build -t openclaw:local -f Dockerfile .

# 2. Add CLIPROXY_API_KEY to docker-compose.yml if not present
if ! grep -q CLIPROXY_API_KEY docker-compose.yml; then
  sed -i '' '/OPENCLAW_GATEWAY_TOKEN/a\
      CLIPROXY_API_KEY: ${CLIPROXY_API_KEY}
' docker-compose.yml
fi

# 3. Prompt for secrets if .env doesn't exist
if [ ! -f .env ]; then
  GATEWAY_TOKEN=$(openssl rand -hex 32)
  read -rp "CLIPROXY_API_KEY: " CLIPROXY_API_KEY
  read -rp "Telegram Bot Token: " TG_TOKEN
  cat > .env <<EOF
OPENCLAW_CONFIG_DIR=$HOME/.openclaw
OPENCLAW_WORKSPACE_DIR=$HOME/.openclaw/workspace
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_GATEWAY_BIND=lan
OPENCLAW_GATEWAY_TOKEN=$GATEWAY_TOKEN
OPENCLAW_IMAGE=openclaw:local
OPENCLAW_EXTRA_MOUNTS=
OPENCLAW_HOME_VOLUME=
OPENCLAW_DOCKER_APT_PACKAGES=
CLIPROXY_API_KEY=$CLIPROXY_API_KEY
EOF
  echo "Generated .env with gateway token: $GATEWAY_TOKEN"
else
  source .env
  TG_TOKEN=""
fi

# 4. Create config dirs
mkdir -p ~/.openclaw ~/.openclaw/workspace ~/.openclaw/identity

# 5. Configure gateway + telegram + cliproxy provider
docker compose run --rm openclaw-cli config set gateway.mode local
docker compose run --rm openclaw-cli config set gateway.auth.token "$OPENCLAW_GATEWAY_TOKEN"
docker compose run --rm openclaw-cli config set gateway.controlUi.allowedOrigins '["http://127.0.0.1:18789"]' --strict-json

if [ -n "$TG_TOKEN" ]; then
  docker compose run --rm openclaw-cli config set channels.telegram.botToken "$TG_TOKEN"
fi

docker compose run --rm openclaw-cli config set agents.defaults.model "cliproxy/claude-sonnet-4-6"

# 6. Start
docker compose up -d openclaw-gateway
echo ""
echo "OpenClaw running at http://127.0.0.1:18789/"
echo "Gateway token: $OPENCLAW_GATEWAY_TOKEN"
