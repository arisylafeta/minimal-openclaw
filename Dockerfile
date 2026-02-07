# syntax=docker/dockerfile:1
# Minimal OpenClaw - Single stage, essential tools only

FROM node:lts-bookworm-slim

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install ONLY essential system tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    jq \
    openssl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set up workspace
WORKDIR /app

# Install OpenClaw globally
RUN npm install -g openclaw && \
    if command -v openclaw >/dev/null 2>&1; then \
    echo "✅ openclaw installed"; \
    else \
    echo "❌ openclaw install failed"; \
    exit 1; \
    fi

# Copy bootstrap script
COPY scripts/bootstrap.sh /app/scripts/bootstrap.sh
RUN chmod +x /app/scripts/bootstrap.sh

# Set environment
ENV HOME=/data \
    OPENCLAW_STATE_DIR=/data/.openclaw \
    OPENCLAW_WORKSPACE=/data/openclaw-workspace

# Expose gateway port
EXPOSE 18789

# Run bootstrap and start
CMD ["bash", "/app/scripts/bootstrap.sh"]
