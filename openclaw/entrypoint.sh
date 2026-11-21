#!/usr/bin/env bash
# Entrypoint of the openclaw image. Runs at each pod start, then hands off to
# the command (the gateway). All steps are idempotent. State is on the PVC at
# /home/node/.openclaw. The root filesystem is read-only in the cluster.
set -euo pipefail

MANIFEST="/opt/config/skills-manifest.txt"
WORKDIR="/home/node/.openclaw/workspace"

###############################################################################
# No workspace templates in the image: the persona files (AGENTS.md, SOUL.md,
# USER.md, ...) are personal and live only in the PVC (restored state).
###############################################################################
mkdir -p "$WORKDIR"

###############################################################################
# Install ClawHub skills from the manifest
# Set OPENCLAW_SKIP_INSTALL=1 to skip skills and plugins (faster start, offline).
###############################################################################
if [[ "${OPENCLAW_SKIP_INSTALL:-0}" != "1" && -f "$MANIFEST" ]]; then
  echo "[entrypoint] Installing ClawHub skills from manifest ..."
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue

    # Manifest refs are @owner/slug. The install dir is the bare slug.
    slug="${line##*/}"
    if [[ "$line" != "skills-sh:composiohq/composio/composio" && -d "$WORKDIR/skills/$slug" ]]; then
      echo "[entrypoint]   ok $line (already installed)"
      continue
    fi
    if [[ "$line" == "skills-sh:composiohq/composio/composio" && -d "$WORKDIR/skills/$slug" ]]; then
      rm -rf "$WORKDIR/skills/$slug" 2>/dev/null || true
    fi

    echo "[entrypoint]   -> installing $line"
    # The official Composio archive has a symlink (.claude/skills) that fails
    # with ArchiveSecurityError. Workaround: shallow clone, drop the symlink,
    # install as a local skill for each agent.
    if [[ "$line" == "skills-sh:composiohq/composio/composio" ]]; then
      TMP_COMPOSIO="/tmp/composio-official-$$"
      if git clone --depth 1 https://github.com/composiohq/composio "$TMP_COMPOSIO" >/dev/null 2>&1; then
        rm -f "$TMP_COMPOSIO/.claude/skills" 2>/dev/null || true
        COMPOSIO_SRC=""
        if [[ -d "$TMP_COMPOSIO/skills/composio" ]]; then
          COMPOSIO_SRC="$TMP_COMPOSIO/skills/composio"
        elif [[ -d "$TMP_COMPOSIO/composio" ]]; then
          COMPOSIO_SRC="$TMP_COMPOSIO/composio"
        fi
        if [[ -n "$COMPOSIO_SRC" ]]; then
          for agent in main builder researcher; do
            openclaw skills install "$COMPOSIO_SRC" --as composio --force --acknowledge-install-policy-warning --agent "$agent" || {
              echo "[entrypoint] WARNING: Failed to install $line for $agent (local workaround), continuing"
            }
          done
        else
          echo "[entrypoint] WARNING: composio skill subdir not found in clone, continuing"
        fi
        rm -rf "$TMP_COMPOSIO" 2>/dev/null || true
      else
        echo "[entrypoint] WARNING: Failed to clone composio repo, trying direct install"
        for agent in main builder researcher; do
          openclaw skills install "$line" --force --acknowledge-install-policy-warning --agent "$agent" || {
            echo "[entrypoint] WARNING: Failed to install $line for $agent, continuing"
          }
        done
      fi
    else
      openclaw skills install "$line" --force --acknowledge-install-policy-warning || {
        echo "[entrypoint] WARNING: Failed to install $line, continuing"
      }
    fi
  done < "$MANIFEST"
  echo "[entrypoint] Skill installation complete."
fi

###############################################################################
# Install plugins from the manifest (pinned versions, no drift)
# INSTALL_LOSSLESS_CLAW=0 skips lossless-claw.
###############################################################################
PLUGINS_MANIFEST="/opt/config/plugins-manifest.txt"
if [[ "${OPENCLAW_SKIP_INSTALL:-0}" != "1" && -f "$PLUGINS_MANIFEST" ]]; then
  echo "[entrypoint] Installing plugins from manifest ..."
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue
    if [[ "$line" == *"lossless-claw"* && "${INSTALL_LOSSLESS_CLAW:-1}" == "0" ]]; then
      echo "[entrypoint]   skip $line (INSTALL_LOSSLESS_CLAW=0)"
      continue
    fi
    echo "[entrypoint]   -> installing $line"
    openclaw plugins install "$line" --force --accept-capabilities 2>&1 || {
      echo "[entrypoint] WARNING: Failed to install $line, continuing"
    }
  done < "$PLUGINS_MANIFEST"
  echo "[entrypoint] Plugin installation complete."
fi

###############################################################################
# Git over SSH for pushes. The key is a Secret mounted read-only at
# /home/node/.ssh-keys/id_github (mode 0400). The root filesystem is read-only,
# so the pod sets GIT_SSH_COMMAND itself (see the Deployment). Nothing to do here.
###############################################################################

echo "[entrypoint] Starting: $*"
exec "$@"
