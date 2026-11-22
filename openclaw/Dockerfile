###############################################################################
# OpenClaw gateway image for the home-cluster k3s node (VPS, linux/amd64).
#
# Source of this image: the old Docker Compose setup in openclaw-prod, trimmed
# for Kubernetes:
#   - no Chromium and no agent-browser (the VPS has no RAM for it; D26),
#   - no sudo (the pod runs non-root with a read-only root filesystem),
#   - no SOPS (secrets are Kubernetes Secrets; the container never decrypts),
#   - sqlite3 and age are in, for the backup CronJob (docs/openclaw-plan.md).
# Runtime installs (plugins and skills) go to the PVC at /home/node/.openclaw.
# Everything else that a skill needs must be installed here at build time.
###############################################################################

# Node 24.16 or newer is required by OpenClaw 2026.9.3+. Renovate bumps both.
FROM node:24.22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    age \
    ca-certificates \
    curl \
    git \
    jq \
    openssh-client \
    python3 \
    sqlite3 \
    tini \
    unzip \
  && rm -rf /var/lib/apt/lists/*

# uv: Python versions and project dependencies.
ARG UV_VERSION=0.12.3
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh \
  && mv /root/.local/bin/uv /usr/local/bin/uv \
  && mv /root/.local/bin/uvx /usr/local/bin/uvx \
  && rm -rf /root/.local

# Composio CLI. Entry point in /usr/local/bin. Login is manual, once:
#   kubectl -n openclaw exec -it deploy/openclaw -- composio login
# The version is pinned: without it, the installer asks the GitHub API for the
# latest release, and that call failed in CI (rate limit). The installer checks
# the archive against the release checksums.txt.
# renovate: datasource=github-releases depName=ComposioHQ/composio extractVersion=^@composio/cli@(?<version>.+)$
ARG COMPOSIO_VERSION=0.6.3
RUN curl -fsSL https://composio.dev/install \
  | COMPOSIO_INSTALL_DIR=/opt/composio COMPOSIO_BIN_DIR=/usr/local/bin COMPOSIO_INSTALL_SHELL=none sh -s -- "${COMPOSIO_VERSION}" \
  && composio --version

# Pinned versions. Renovate bumps them (see renovate.json). An OpenClaw bump on
# an existing PVC needs the doctor run: docs/openclaw-plan.md, "Upgrades".
# renovate: datasource=npm depName=openclaw
ARG OPENCLAW_VERSION=2026.10.9
# renovate: datasource=npm depName=clawhub
ARG CLAWHUB_VERSION=0.27.0
# renovate: datasource=npm depName=@steipete/summarize
ARG SUMMARIZE_VERSION=0.25.3
# renovate: datasource=npm depName=acpx
ARG ACPX_VERSION=0.13.0
# Stable v2 channel (npm "latest" of @opencode/cli). Not the beta channel.
# renovate: datasource=npm depName=@opencode/cli
ARG OPENCODE_CLI_VERSION=2.3.2

RUN npm install -g \
    openclaw@${OPENCLAW_VERSION} \
    clawhub@${CLAWHUB_VERSION} \
    @steipete/summarize@${SUMMARIZE_VERSION} \
    acpx@${ACPX_VERSION} \
    @opencode/cli@${OPENCODE_CLI_VERSION} \
  && npm cache clean --force \
  && mkdir -p /home/node/.openclaw/workspace /.clawhub \
  && chown -R node:node /home/node /.clawhub

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER node

# Git identity of the agent. Override with GIT_CONFIG_* env in the pod.
ARG GIT_USER_NAME="OpenClaw"
ARG GIT_USER_EMAIL="openclaw@users.noreply.local"
RUN git config --global user.name "${GIT_USER_NAME}" \
 && git config --global user.email "${GIT_USER_EMAIL}"

ENV HOME=/home/node \
    NODE_PATH=/usr/local/lib/node_modules \
    NODE_ENV=production \
    XDG_CACHE_HOME=/home/node/.openclaw/.cache

EXPOSE 18789
ENTRYPOINT ["/usr/bin/tini", "--", "entrypoint.sh"]
CMD ["openclaw", "gateway", "--bind", "lan", "--port", "18789"]
