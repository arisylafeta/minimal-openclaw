# OpenClaw: Original vs Minimal Comparison

## Architecture Comparison

### Original (4 Services, 5 Volumes)

```yaml
services:
  - openclaw (main)
  - docker-proxy (security)
  - searxng (search engine)
  - registry (Docker registry)

volumes:
  - openclaw-data
  - openclaw-config
  - openclaw-workspace
  - searxng-data
  - registry-data
```

### Minimal (2 Services, 2 Volumes)

```yaml
services:
  - openclaw (main)
  - docker-proxy (security)

volumes:
  - openclaw-data
  - openclaw-workspace
```

## Dockerfile Comparison

### Original
- **Stages**: 5 multi-stage builds
- **Base**: node:lts-bookworm-slim + extensive packages
- **Tools**: Python3, Go, Docker CLI, Cloudflared, GH CLI, Bun, Chromium, FFmpeg, Pandoc, etc.
- **AI CLIs**: Claude, Kimi, OpenAI Codex, Gemini, Opencode, Hyperbrowser, Clawhub
- **Size**: ~2GB

### Minimal
- **Stages**: 1 single stage
- **Base**: node:lts-bookworm-slim
- **Tools**: curl, git, jq, openssl (essential only)
- **AI CLIs**: None (openclaw package only)
- **Size**: ~500MB

## Service-by-Service Analysis

### ✅ KEEP: openclaw (Main Service)
**Purpose**: Core gateway and orchestrator
**Dependencies**: docker-proxy
**Original Config**:
- 40+ environment variables
- 3 volumes
- Complex healthcheck
- File descriptor limits
- Build args

**Minimal Config**:
- 10 environment variables
- 2 volumes
- Standard healthcheck
- No special limits

### ✅ KEEP: docker-proxy (Security)
**Purpose**: Secure Docker socket access
**Original**: Same
**Minimal**: Same (critical for security)

### ❌ REMOVE: searxng (Search Engine)
**Purpose**: Private meta-search
**Why Optional**:
- OpenClaw can use external search APIs
- Adds ~256MB RAM usage
- Requires separate volume
- Adds build complexity

**Migration**: Use external search or add back as needed

### ❌ REMOVE: registry (Docker Registry)
**Purpose**: Local image storage
**Why Optional**:
- OpenClaw pulls from Docker Hub
- Adds ~128MB RAM
- Not required for core sandboxing
- Registry data volume not needed

**Migration**: Sandboxes pull images directly

## Environment Variables Removed

### Removed (Optional Integrations)
```bash
# AI Providers (keep only ONE)
MINIMAX_API_KEY
# ANTHROPIC_API_KEY (optional)
# GEMINI_API_KEY (optional)
KIMI_API_KEY
OPENCODE_API_KEY
MOONSHOT_API_KEY

# Optional Services
GOOGLE_MAPS_API_KEY
NANOBANANA_API_KEY
ELEVENLABS_API_KEY

# Public Access
CF_TUNNEL_TOKEN

# Deployment
VERCEL_ORG_ID
VERCEL_PROJECT_ID
VERCEL_TOKEN

# Git Operations
GITHUB_TOKEN
GITHUB_USERNAME
GITHUB_EMAIL

# Advanced
OPENCLAW_BETA
OPENCLAW_ENABLE_WEBHOOK_PROXY
SERVICE_URL_OPENCLAW_18789
SERVICE_URL_OPENCLAWWEBHOOK_8788
BASE_URL
PUBLIC_URL
SERVICE_FQDN_OPENCLAW
GATEWAY_TRUSTED_PROXIES
CHOKIDAR_USEPOLLING
```

### Kept (Essential)
```bash
# Docker
DOCKER_HOST=tcp://docker-proxy:2375

# OpenClaw Core
PORT=18789
NODE_ENV=production
HOME=/data
OPENCLAW_STATE_DIR=/data/.openclaw
OPENCLAW_WORKSPACE=/data/openclaw-workspace
OPENCLAW_GATEWAY_PORT
OPENCLAW_GATEWAY_BIND

# AI (ONE required)
OPENAI_API_KEY

# Optional but useful
TELEGRAM_BOT_TOKEN

# Bootstrap
OPENCLAW_AUTO_BOOTSTRAP
OPENCLAW_PRINT_ACCESS
```

## Volume Comparison

### Original Volumes
1. `openclaw-data` → /data (user data, configs, CLI tools)
2. `openclaw-config` → /root/.openclaw (OpenClaw specific config)
3. `openclaw-workspace` → /root/openclaw-workspace (projects)
4. `searxng-data` → /var/lib/searxng (search data)
5. `registry-data` → /var/lib/registry (Docker images)

### Minimal Volumes
1. `openclaw-data` → /data (merged: data + config)
2. `openclaw-workspace` → /data/openclaw-workspace (projects)

**Merged**: openclaw-config into openclaw-data (same physical location)

## Scripts Comparison

### Original Scripts
- `bootstrap.sh` - 214 lines (complex agent seeding, config gen, recovery)
- `migrate-to-data.sh` - Data migration
- `recover_sandbox.sh` - Recovery protocol
- `monitor_sandbox.sh` - Health monitoring
- `sandbox-setup.sh` - Sandbox base image
- `sandbox-browser-setup.sh` - Browser setup
- `openclaw-approve.sh` - Pairing approval

### Minimal Scripts
- `bootstrap.sh` - 70 lines (simple config gen, startup)

**Removed**: Recovery, monitoring, migration, complex seeding

## Use Cases

### Use Original If:
- You need all AI providers
- You want built-in web search
- You need local Docker registry
- You want automatic recovery
- You need browser automation
- You deploy to Vercel frequently
- You use Cloudflare tunnels
- Storage space isn't a concern

### Use Minimal If:
- You only need one AI provider
- You want faster startup
- Storage/transfer is limited
- You're testing/developing
- You can add tools on-demand
- You want simpler maintenance
- You use external services for search

## Resource Usage

| Resource | Original | Minimal | Savings |
|----------|----------|---------|---------|
| **Image Size** | ~2GB | ~500MB | 75% |
| **Services** | 4 | 2 | 50% |
| **Volumes** | 5 | 2 | 60% |
| **RAM (idle)** | ~512MB | ~256MB | 50% |
| **Startup Time** | ~60s | ~10s | 83% |
| **Build Time** | ~10min | ~2min | 80% |

## Migration Path

### From Original to Minimal:

1. **Backup your data**:
   ```bash
   docker-compose down
   cp -r /path/to/openclaw-data ./backup-data
   cp -r /path/to/openclaw-workspace ./backup-workspace
   ```

2. **Switch to minimal**:
   ```bash
   cd minimal-openclaw
   cp .env.example .env
   # Edit .env with your API key
   ```

3. **Restore data** (optional):
   ```bash
   # Mount backup volumes to minimal
   ```

### From Minimal to Original:

Simply switch back to the original docker-compose.yaml and Dockerfile. Data should remain compatible.

## Testing Checklist

### Minimal Config Tests
- [ ] `docker-compose up -d` starts successfully
- [ ] Gateway responds on port 18789
- [ ] Can access web UI with token
- [ ] Can create sandboxes
- [ ] Sandboxes can pull images
- [ ] Workspace persists after restart
- [ ] Telegram bot works (if configured)

### Missing Features Tests
- [ ] Web search (will fail without SearXNG)
- [ ] Local registry (will use Docker Hub)
- [ ] Recovery (manual restart needed)
- [ ] Cloudflare tunnel (manual setup needed)

## Recommendations

1. **Start with Minimal**: Test core functionality
2. **Add back as needed**: Only add services you actually use
3. **Monitor usage**: Check if you miss any removed features
4. **Hybrid approach**: Use minimal for dev, original for production
