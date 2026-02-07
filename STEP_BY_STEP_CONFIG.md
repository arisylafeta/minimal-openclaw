# Step-by-Step Configuration Guide

## Original OpenClaw Config (Essamamdani)

### Step 1: Docker Compose Environment Variables
**Location**: `docker-compose.yaml` lines 21-83

The compose file defines 40+ environment variables that get injected into the container:

```yaml
environment:
  # System/Container config
  DOCKER_HOST: tcp://docker-proxy:2375
  PORT: 18789                    # Hardcoded port
  NODE_ENV: production
  HOME: /data
  
  # Persistence paths
  HISTFILE: /data/.bash_history
  XDG_CONFIG_HOME: /data/.config
  NPM_CONFIG_CACHE: /data/.npm
  BUN_INSTALL: /data/.bun
  
  # OpenClaw specific
  OPENCLAW_GATEWAY_PORT: ${OPENCLAW_GATEWAY_PORT:-18789}  # Uses default if not set
  OPENCLAW_STATE_DIR: /data/.openclaw
  OPENCLAW_WORKSPACE: /data/openclaw-workspace
  
  # API Keys - user provides what they have
  OPENAI_API_KEY: ${OPENAI_API_KEY}
  ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY}
  # ... 40+ more variables
```

**What happens**: Docker reads `.env` file or uses values from shell, substitutes them into the compose file.

### Step 2: Container Startup
**Command**: `bash /app/scripts/bootstrap.sh`

Docker runs the bootstrap script which orchestrates the entire setup.

### Step 3: Data Migration (Optional)
**Script**: Lines 4-6 of bootstrap.sh

```bash
if [ -f "/app/scripts/migrate-to-data.sh" ]; then
    bash "/app/scripts/migrate-to-data.sh"
fi
```

Checks if old data needs migration from previous installations.

### Step 4: Directory Structure Setup
**Script**: Lines 8-23

```bash
OPENCLAW_STATE="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
mkdir -p "$OPENCLAW_STATE" "$WORKSPACE_DIR"
mkdir -p "$OPENCLAW_STATE/credentials"
mkdir -p "$OPENCLAW_STATE/agents/main/sessions"

# Create symlinks for CLI tool configs
for dir in .agents .ssh .config .local .cache .npm .bun .claude .kimi; do
    ln -sf "/data/$dir" "/root/$dir"
done
```

Creates:
- State directory: `/data/.openclaw`
- Workspace: `/data/openclaw-workspace`
- Agent sessions: `/data/.openclaw/agents/main/sessions`
- Credentials: `/data/.openclaw/credentials`

Sets up symlinks so CLI tools store configs in persistent volumes.

### Step 5: Agent Workspace Seeding
**Script**: Lines 28-65

```bash
seed_agent() {
  local id="$1"
  local name="$2"
  local dir="/data/openclaw-$id"
  
  if [ "$id" = "main" ]; then
    dir="${OPENCLAW_WORKSPACE:-/data/openclaw-workspace}"
  fi

  # 🔒 NEVER overwrite existing SOUL.md
  if [ -f "$dir/SOUL.md" ]; then
    echo "🧠 SOUL.md already exists for $id — skipping"
    return 0
  fi

  # ✅ MAIN agent gets ORIGINAL repo SOUL.md
  if [ "$id" = "main" ]; then
    cp "./SOUL.md" "$dir/SOUL.md"
    cp "./BOOTSTRAP.md" "$dir/BOOTSTRAP.md"
  fi
}

seed_agent "main" "OpenClaw"
```

Copies personality/instruction files to workspace:
- `SOUL.md` - AI personality and rules
- `BOOTSTRAP.md` - Additional instructions

Only happens on first run (checks if files exist).

### Step 6: Generate openclaw.json Config
**Script**: Lines 70-148

```bash
if [ ! -f "$CONFIG_FILE" ]; then
  TOKEN=$(openssl rand -hex 24)
  cat >"$CONFIG_FILE" <<EOF
{
  "commands": {
    "native": true,
    "nativeSkills": true,
    "text": true,
    "bash": true,
    "config": true,
    "debug": true,
    "restart": true,
    "useAccessGroups": true
  },
  "plugins": {
    "enabled": true,
    "entries": {
      "whatsapp": { "enabled": true },
      "telegram": { "enabled": true },
      "google-antigravity-auth": { "enabled": true }
    }
  },
  "skills": {
    "allowBundled": ["*"],
    "install": { "nodeManager": "npm" }
  },
  "gateway": {
    "port": $OPENCLAW_GATEWAY_PORT,
    "mode": "local",
    "bind": "lan",
    "controlUi": { "enabled": true, "allowInsecureAuth": false },
    "trustedProxies": ["*"],
    "tailscale": { "mode": "off", "resetOnExit": false },
    "auth": { "mode": "token", "token": "$TOKEN" }
  },
  "agents": {
    "defaults": {
      "workspace": "$WORKSPACE_DIR",
      "envelopeTimestamp": "on",
      "envelopeElapsed": "on",
      "cliBackends": {},
      "heartbeat": { "every": "1h" },
      "maxConcurrent": 4,
      "sandbox": {
        "mode": "non-main",
        "scope": "session",
        "browser": { "enabled": true }
      }
    },
    "list": [
      { "id": "main","default": true, "name": "default", "workspace": "..."}
    ]
  }
}
EOF
fi
```

Generates `openclaw.json` with:
- **7 command types** - native, skills, text, bash, config, debug, restart
- **3 plugins** - whatsapp, telegram, google-auth (all enabled)
- **Skills config** - Allow all bundled skills, use npm
- **Gateway** - Port 18789, local mode, control UI, tailscale off, token auth
- **Agents** - 4 max concurrent, heartbeat every hour, browser enabled

Token is randomly generated on first run.

### Step 7: Sandbox Setup Scripts
**Script**: Lines 158-159

```bash
[ -f scripts/sandbox-setup.sh ] && bash scripts/sandbox-setup.sh
[ -f scripts/sandbox-browser-setup.sh ] && bash scripts/sandbox-browser-setup.sh
```

Runs optional setup scripts:
- `sandbox-setup.sh` - Creates sandbox base image from python:3.11-slim
- `sandbox-browser-setup.sh` - Configures browser automation

### Step 8: Recovery & Monitoring
**Script**: Lines 164-175

```bash
if [ -f scripts/recover_sandbox.sh ]; then
  cp scripts/recover_sandbox.sh "$WORKSPACE_DIR/"
  cp scripts/monitor_sandbox.sh "$WORKSPACE_DIR/"
  chmod +x "$WORKSPACE_DIR/recover_sandbox.sh" "$WORKSPACE_DIR/monitor_sandbox.sh"
  
  bash "$WORKSPACE_DIR/recover_sandbox.sh"
  nohup bash "$WORKSPACE_DIR/monitor_sandbox.sh" >/dev/null 2>&1 &
fi
```

Sets up background processes:
- **Recovery script** - Restarts stopped containers on startup
- **Monitor script** - Runs every 5 minutes to check health

### Step 9: Token Extraction
**Script**: Lines 185-190

```bash
if [ -f "$CONFIG_FILE" ]; then
    SAVED_TOKEN=$(jq -r '.gateway.auth.token // empty' "$CONFIG_FILE")
    if [ -n "$SAVED_TOKEN" ]; then
        TOKEN="$SAVED_TOKEN"
    fi
fi
```

Reads the token from the previously generated config file for display.

### Step 10: Display Access Info & Start
**Script**: Lines 192-214

```bash
echo "🦞 OpenClaw is ready!"
echo "🔑 Access Token: $TOKEN"
echo "🌍 Service URL (Local): http://localhost:${OPENCLAW_GATEWAY_PORT:-18789}?token=$TOKEN"
if [ -n "$SERVICE_FQDN_OPENCLAW" ]; then
    echo "☁️  Service URL (Public): https://${SERVICE_FQDN_OPENCLAW}?token=$TOKEN"
fi
echo "👉 Onboarding:"
echo "   1. Access the UI using the link above."
echo "   2. To approve this machine, run: openclaw-approve"
echo "   3. To start the onboarding wizard: openclaw onboard"

ulimit -n 65535
exec openclaw gateway run
```

Displays access information and starts the OpenClaw gateway process.

---

## Minimal OpenClaw Config (EasyClaw)

### Step 1: Docker Compose Environment Variables
**Location**: `docker-compose.yaml` lines 13-47

```yaml
environment:
  # Required - set by backend
  PORT: ${OPENCLAW_GATEWAY_PORT}
  OPENCLAW_GATEWAY_PORT: ${OPENCLAW_GATEWAY_PORT}
  OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
  CONTAINER_ID: ${CONTAINER_ID:-}
  CONTAINER_NAME: ${CONTAINER_NAME:-}
  
  # Core OpenClaw config
  DOCKER_HOST: tcp://docker-proxy:2375
  NODE_ENV: production
  HOME: /data
  OPENCLAW_STATE_DIR: ${OPENCLAW_STATE_DIR:-/data/.openclaw}
  OPENCLAW_WORKSPACE: ${OPENCLAW_WORKSPACE:-/data/openclaw-workspace}
  OPENCLAW_GATEWAY_BIND: ${OPENCLAW_GATEWAY_BIND:-lan}
  
  # AI providers (user provides what they have)
  OPENAI_API_KEY: ${OPENAI_API_KEY:-}
  ANTHROPIC_API_KEY: ${ANTHROPIC_API_KEY:-}
  GEMINI_API_KEY: ${GEMINI_API_KEY:-}
  # ... 20+ more optional vars
```

**Key differences from original**:
- Port is dynamic `${OPENCLAW_GATEWAY_PORT}` (no default)
- Token comes from backend `${OPENCLAW_GATEWAY_TOKEN}`
- Container identification for backend tracking
- Uses `${VAR:-}` syntax (empty default) for optional vars

### Step 2: Container Startup
**Command**: `bash /app/scripts/bootstrap.sh`

Same as original - Docker runs the bootstrap script.

### Step 3: Read Environment Variables
**Script**: Lines 5-9

```bash
OPENCLAW_STATE="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
CONFIG_FILE="$OPENCLAW_STATE/openclaw.json"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-/data/openclaw-workspace}"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"
```

Reads configuration from environment variables with fallbacks.

### Step 4: Simple Directory Structure
**Script**: Lines 12-16

```bash
mkdir -p "$OPENCLAW_STATE" "$WORKSPACE_DIR"
chmod 700 "$OPENCLAW_STATE"
mkdir -p "$OPENCLAW_STATE/credentials"
chmod 700 "$OPENCLAW_STATE/credentials"
```

Creates simplified structure:
- State: `/data/.openclaw`
- Workspace: `/data/openclaw-workspace`
- Credentials: `/data/.openclaw/credentials`

No agent subdirectories (simpler).

### Step 5: Essential Symlinks Only
**Script**: Lines 19-23

```bash
for dir in .ssh .config .local .cache .npm; do
    if [ ! -L "/root/$dir" ] && [ ! -e "/root/$dir" ]; then
        ln -sf "/data/$dir" "/root/$dir"
    fi
done
```

Only core symlinks (removed .bun, .claude, .kimi, .agents).

### Step 6: Token Handling
**Script**: Lines 26-35

```bash
if [ -z "$GATEWAY_TOKEN" ]; then
    echo "⚠️  No OPENCLAW_GATEWAY_TOKEN provided, generating new token..."
    GATEWAY_TOKEN=$(openssl rand -hex 24)
fi

# Validate AI provider keys
if [ -z "$OPENAI_API_KEY" ] && [ -z "$ANTHROPIC_API_KEY" ] && ...; then
    echo "⚠️  Warning: No AI provider API key detected."
fi
```

**Key differences**:
- Accepts token from environment (backend-provided)
- OR generates one if not provided
- Warns if no AI provider keys are set

### Step 7: Generate Minimal openclaw.json
**Script**: Lines 38-67

```bash
if [ ! -f "$CONFIG_FILE" ]; then
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
        "enabled": ${TELEGRAM_BOT_TOKEN:+true}${TELEGRAM_BOT_TOKEN:-false}
      }
    }
  },
  "gateway": {
    "port": $GATEWAY_PORT,
    "bind": "${OPENCLAW_GATEWAY_BIND:-lan}",
    "auth": { "mode": "token", "token": "$GATEWAY_TOKEN" }
  },
  "agents": {
    "defaults": {
      "workspace": "$WORKSPACE_DIR",
      "maxConcurrent": 2
    },
    "list": [
      { "id": "main", "default": true, "workspace": "$WORKSPACE_DIR" }
    ]
  }
}
EOF
fi
```

Generates minimal `openclaw.json` with:
- **4 command types** - native, text, bash, config (core only)
- **1 plugin** - telegram (conditional on TELEGRAM_BOT_TOKEN)
- **Gateway** - Dynamic port, token from env/backend
- **Agents** - 2 max concurrent, no heartbeat, no browser config

**Key differences**:
- Port is dynamic from `$GATEWAY_PORT`
- Token from `$GATEWAY_TOKEN` (backend or generated)
- Telegram only enabled if token provided
- Much simpler config (12 fields vs 23)

### Step 8: Export State
**Script**: Line 70

```bash
export OPENCLAW_STATE_DIR="$OPENCLAW_STATE"
```

Exports for OpenClaw runtime.

### Step 9: Display Access Info & Start
**Script**: Lines 73-90

```bash
echo "🦞 Minimal OpenClaw is ready!"
echo "🔑 Access Token: $GATEWAY_TOKEN"
echo "🌍 Local URL: http://localhost:$GATEWAY_PORT?token=$GATEWAY_TOKEN"
if [ -n "$CONTAINER_NAME" ]; then
    echo "📦 Container: $CONTAINER_NAME"
fi
if [ -n "$CONTAINER_ID" ]; then
    echo "🆔 Container ID: $CONTAINER_ID"
fi

exec openclaw gateway run
```

Displays access info (simpler banner) and starts OpenClaw.

**Key differences**:
- Shows container ID/name for backend tracking
- No onboarding instructions (assumes EasyClaw backend manages it)
- No mention of recovery/monitoring

---

## Backend Integration Flow (EasyClaw)

### How EasyClaw Backend Uses the Minimal Config

```javascript
// In backend/src/services/container-deployment.ts

// Step 1: Allocate free port
const gatewayPort = await portAllocationService.allocatePort(serverId);
// Returns: 18789, 18790, 18791, etc.

// Step 2: Generate secure token
const gatewayToken = generateGatewayToken();
// Returns: "a1b2c3d4e5f6..." (32+ chars)

// Step 3: Create Coolify application
const application = await coolifyProvider.applications.createApplicationFromPublicGit({
  name: containerName,
  gitRepository: 'https://github.com/essamamdani/openclaw-coolify',
  // ...
});

// Step 4: Set environment variables via Coolify API
const envVars = {
  CONTAINER_ID: applicationId,              // For backend tracking
  CONTAINER_NAME: containerName,            // For backend tracking
  OPENCLAW_GATEWAY_PORT: gatewayPort.toString(),  // Dynamic port
  OPENCLAW_GATEWAY_TOKEN: gatewayToken,     // Backend-generated token
  OPENAI_API_KEY: request.envVars.OPENAI_API_KEY, // User-provided
  TELEGRAM_BOT_TOKEN: request.envVars.TELEGRAM_BOT_TOKEN,
  // ... other user vars
};

await coolifyProvider.applications.setEnvironmentVariables(
  application.uuid,
  Object.entries(envVars).map(([key, value]) => ({
    key,
    value,
    is_runtime: true,
    is_buildtime: false,
  }))
);

// Step 5: Trigger deployment
await coolifyProvider.applications.deployApplication(application.uuid, true);
```

**What happens**:
1. Backend allocates port (e.g., 18789)
2. Backend generates token
3. Backend creates Coolify app from Git repo
4. Backend injects all env vars including port and token
5. Bootstrap script reads these and generates config
6. OpenClaw starts on the allocated port with the provided token

---

## Comparison Table

| Step | Original | Minimal | Purpose |
|------|----------|---------|---------|
| **1. Env Vars** | 40+ explicit vars | 20 vars with defaults | Inject configuration |
| **2. Migration** | Yes (checks for old data) | No | Data compatibility |
| **3. Directories** | Complex (agents, sessions) | Simple (state, workspace) | Persistence setup |
| **4. Symlinks** | 8 directories | 5 directories | CLI config storage |
| **5. Seeding** | SOUL.md + BOOTSTRAP.md | None | Personality files |
| **6. Config Gen** | 23 fields, 7 commands | 12 fields, 4 commands | openclaw.json |
| **7. Sandbox Setup** | Pre-configures images | Runtime install | Sandboxing |
| **8. Recovery** | Recovery + monitor scripts | None | Auto-restart |
| **9. Token** | Extract from config file | Use from env or generate | Authentication |
| **10. Display** | Detailed onboarding | Simple + container info | User access |

---

## Key Configuration Files

### Original Config Chain
```
docker-compose.yaml (40+ env vars)
    ↓
bootstrap.sh (214 lines)
    ├── migrate-to-data.sh (optional)
    ├── seed_agent() (copies SOUL.md)
    ├── sandbox-setup.sh (pre-configures)
    ├── sandbox-browser-setup.sh (browser)
    ├── recover_sandbox.sh (recovery)
    └── monitor_sandbox.sh (monitoring)
    ↓
openclaw.json (23 fields, complex)
    ↓
OpenClaw Runtime
```

### Minimal Config Chain
```
docker-compose.yaml (20 env vars, dynamic port/token)
    ↓
bootstrap.sh (91 lines)
    ├── Simple directory setup
    ├── Read env vars
    └── Generate config
    ↓
openclaw.json (12 fields, minimal)
    ↓
OpenClaw Runtime
```

---

## Common Patterns

Both configs follow these patterns:

1. **Environment Variable Injection**: Docker Compose → Container
2. **Bootstrap Orchestration**: Single script coordinates setup
3. **Config File Generation**: JSON file created if not exists
4. **Persistence**: Volumes mounted for data survival
5. **Token-based Auth**: Random token generated for security
6. **Port Configuration**: Gateway runs on specified port
7. **Plugin System**: Telegram/WhatsApp enabled via env vars

The main difference is **scope** - original does everything upfront, minimal assumes runtime configuration and backend management.
