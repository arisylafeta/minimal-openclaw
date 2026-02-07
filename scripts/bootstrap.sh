#!/usr/bin/env bash
set -e

# Use environment variables or defaults
OPENCLAW_STATE="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
CONFIG_FILE="$OPENCLAW_STATE/openclaw.json"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-/data/openclaw-workspace}"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

# Create directories
mkdir -p "$OPENCLAW_STATE" "$WORKSPACE_DIR"
chmod 700 "$OPENCLAW_STATE"

mkdir -p "$OPENCLAW_STATE/credentials"
chmod 700 "$OPENCLAW_STATE/credentials"

# Create symlinks for persistence
for dir in .ssh .config .local .cache .npm; do
    if [ ! -L "/root/$dir" ] && [ ! -e "/root/$dir" ]; then
        ln -sf "/data/$dir" "/root/$dir"
    fi
done

# Use token from environment or generate one
if [ -z "$GATEWAY_TOKEN" ]; then
    echo "⚠️  No OPENCLAW_GATEWAY_TOKEN provided, generating new token..."
    GATEWAY_TOKEN=$(openssl rand -hex 24 2>/dev/null || node -e "console.log(require('crypto').randomBytes(24).toString('hex'))")
fi

# Validate that at least one AI provider key is set
if [ -z "$OPENAI_API_KEY" ] && [ -z "$ANTHROPIC_API_KEY" ] && [ -z "$GEMINI_API_KEY" ] && \
   [ -z "$MINIMAX_API_KEY" ] && [ -z "$KIMI_API_KEY" ] && [ -z "$OPENCODE_API_KEY" ] && \
   [ -z "$MOONSHOT_API_KEY" ]; then
    echo "⚠️  Warning: No AI provider API key detected. OpenClaw will not be able to process AI requests."
    echo "    Set at least one of: OPENAI_API_KEY, ANTHROPIC_API_KEY, GEMINI_API_KEY, etc."
fi

# Determine telegram enabled state
TELEGRAM_ENABLED="false"
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    TELEGRAM_ENABLED="true"
fi

# Generate config if missing (or use provided token)
if [ ! -f "$CONFIG_FILE" ]; then
    echo "🏥 Generating openclaw.json..."
    
    cat >"$CONFIG_FILE" <<EOF
{
  "commands": {
    "native": true,
    "text": true,
    "bash": true,
    "config": true
  },
  "plugins": {
    "enabled": true,
    "entries": {
      "telegram": {
        "enabled": ${TELEGRAM_ENABLED}
      }
    }
  },
  "gateway": {
    "port": ${GATEWAY_PORT},
    "bind": "${OPENCLAW_GATEWAY_BIND:-lan}",
    "auth": { "mode": "token", "token": "${GATEWAY_TOKEN}" }
  },
  "agents": {
    "defaults": {
      "workspace": "${WORKSPACE_DIR}",
      "maxConcurrent": 2
    },
    "list": [
      { "id": "main", "default": true, "workspace": "${WORKSPACE_DIR}" }
    ]
  }
}
EOF
fi

# Debug: Show generated config
echo "📄 Generated config:"
cat "$CONFIG_FILE"

# Export state
export OPENCLAW_STATE_DIR="$OPENCLAW_STATE"

echo ""
echo "=================================================================="
echo "🦞 Minimal OpenClaw is ready!"
echo "=================================================================="
echo ""
echo "🔑 Access Token: $GATEWAY_TOKEN"
echo ""
echo "🌍 Local URL: http://localhost:$GATEWAY_PORT?token=$GATEWAY_TOKEN"
if [ -n "$CONTAINER_NAME" ]; then
    echo "📦 Container: $CONTAINER_NAME"
fi
if [ -n "$CONTAINER_ID" ]; then
    echo "🆔 Container ID: $CONTAINER_ID"
fi
echo ""
echo "=================================================================="

# Run OpenClaw
exec openclaw gateway run
