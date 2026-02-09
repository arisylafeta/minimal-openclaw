# OpenClaw Docker Template

A minimal, production-ready Docker template for running [OpenClaw](https://github.com/openclaw/openclaw) — an AI agent framework that lets you run AI agents in secure sandboxed containers.

## What is OpenClaw?

OpenClaw allows you to:
- **Spawn AI agents** that can run code, execute commands, and work on tasks
- **Sandbox everything** — each agent runs in its own isolated Docker container
- **Access via web UI or Telegram** — interact with your agents through multiple interfaces
- **Preserve state** — your agents' data persists across restarts

## Requirements

- Docker and Docker Compose
- At least **one AI provider API key** (OpenAI, Anthropic, Google, etc.)
- Linux/macOS host (Windows with WSL2 also works)

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/arisylafeta/minimal-openclaw.git
cd minimal-openclaw
cp .env.example .env
```

### 2. Set your AI API key

Edit `.env` and add at least one AI provider API key:

```bash
# Option 1: OpenAI
OPENAI_API_KEY=sk-your_key_here

# Option 2: Anthropic (Claude)
ANTHROPIC_API_KEY=sk-ant-your_key_here

# Option 3: Google (Gemini)
GEMINI_API_KEY=your_key_here

# See .env.example for more providers
```

### 3. Start the services

```bash
docker-compose up -d
```

### 4. Access OpenClaw

Check the logs for your access URL:

```bash
docker-compose logs -f openclaw
```

You'll see output like:
```
🔑 Access Token: abc123def456...
🌍 Local URL: http://localhost:18789?token=abc123def456...
```

Open the URL in your browser to access the OpenClaw web interface.

## Configuration

### Required Variables

| Variable | Description |
|----------|-------------|
| `OPENCLAW_GATEWAY_PORT` | Port for the web interface (default: 18789) |
| `OPENCLAW_GATEWAY_TOKEN` | Authentication token (auto-generated if not set) |
| `OPENAI_API_KEY` | OpenAI API key (or another provider) |

### Optional Variables

| Variable | Description |
|----------|-------------|
| `TELEGRAM_BOT_TOKEN` | Enable Telegram bot interface |
| `GITHUB_TOKEN` | Allow agents to interact with GitHub |
| `VERCEL_TOKEN` | Enable Vercel deployments from agents |
| `CF_TUNNEL_TOKEN` | Expose via Cloudflare tunnel |

See `.env.example` for the complete list.

## How It Works

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   You (Browser) │────▶│  OpenClaw Gateway│────▶│  AI Agent       │
│   or Telegram   │     │  (Web Interface) │     │  (Sandboxed     │
└─────────────────┘     └────────┬─────────┘     │   Container)    │
                                 │               └─────────────────┘
                                 │
                                 ▼
                        ┌──────────────────┐
                        │  Docker Proxy    │
                        │  (Manages        │
                        │   sandboxes)     │
                        └──────────────────┘
```

1. **You** access the OpenClaw web interface
2. **OpenClaw Gateway** handles authentication and routing
3. **AI Agents** run in isolated Docker containers spawned on-demand
4. **Docker Proxy** securely manages container lifecycle

## Security

- Each AI agent runs in its own isolated Docker container
- No direct access to host Docker socket (goes through proxy)
- Authentication required via token
- Sandboxes are ephemeral but can persist data to volumes

## Troubleshooting

### Container won't start

Check logs:
```bash
docker-compose logs openclaw
```

Common issues:
- **Missing API key**: Ensure at least one AI provider key is set
- **Port conflict**: Change `OPENCLAW_GATEWAY_PORT` if 18789 is in use

### Can't access the web interface

- Verify the container is running: `docker-compose ps`
- Check the token in logs: `docker-compose logs openclaw | grep "Access Token"`
- Ensure the port isn't blocked by firewall

### Agents can't spawn sandboxes

- Verify docker-proxy is running: `docker-compose ps`
- Check Docker socket permissions

## Extending

### Add web search capability

Add SearXNG to `docker-compose.yaml`:

```yaml
searxng:
  image: searxng/searxng:latest
  volumes:
    - searxng-data:/var/lib/searxng
  environment:
    SEARXNG_BASE_URL: http://searxng:8080
```

### Add more tools to agents

Edit the `Dockerfile` to install additional tools:

```dockerfile
RUN apt-get update && apt-get install -y \
    python3 \
    nodejs \
    your-tool \
    && rm -rf /var/lib/apt/lists/*
```

## Data Persistence

Your data is stored in two Docker volumes:

- `openclaw-data` — Configuration, credentials, and state
- `openclaw-workspace` — Agent workspaces and files

To backup:
```bash
docker run --rm -v openclaw-data:/data -v $(pwd):/backup alpine tar czf /backup/openclaw-backup.tar.gz -C /data .
```

## License

MIT License — see LICENSE file for details.

OpenClaw itself is created by [@steipete](https://github.com/openclaw/openclaw).
