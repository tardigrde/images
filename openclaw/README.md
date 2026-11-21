# openclaw-image

The OpenClaw gateway for the home-cluster k3s VPS. `linux/amd64` only.
Image: `ghcr.io/tardigrde/openclaw-image`. Tags: `<openclaw version>`, `latest`,
`<openclaw version>-<git sha>`. Pin the tag and the digest in the cluster repo.

Nothing private goes into the image. Tokens, keys and the config come in at
runtime (Secrets and the PVC in `tardigrde/home-cluster`, `k8s/apps/openclaw`).

## What is inside

- Node 24 (Debian bookworm slim), `git`, `curl`, `jq`, `python3`, `openssh-client`,
  `sqlite3`, `age`, `tini`.
- `openclaw`, `clawhub`, `summarize`, `acpx`, and the opencode v2 CLI (`opencode`).
- SOPS (signature checked with cosign at build time), `uv`, Composio CLI.
- No Chromium, no agent-browser, no sudo (decision D26 in home-cluster).

## Start

`entrypoint.sh` installs the skills and plugins from the manifests into the PVC,
then runs `openclaw gateway --bind lan --port 18789`. There are no workspace
templates in the image: persona files are personal and live only in the PVC.
`OPENCLAW_SKIP_INSTALL=1` skips the skill and plugin install.

The skill list is read from `$OPENCLAW_SKILLS_MANIFEST`. The cluster sets it to
a ConfigMap in `tardigrde/home-cluster` (`k8s/apps/openclaw/skills-manifest.txt`),
so a new ClawHub skill needs no image rebuild. There is no skill list in the
image: if the variable is not set, no skills are installed. The plugin list
stays in the image (`plugins-manifest.txt`, pinned versions).

## Update

Renovate bumps the `ARG` versions in `Dockerfile`. A new OpenClaw version on an
existing PVC needs the doctor run first (see `docs/openclaw-plan.md` in
home-cluster, section "Upgrades").

## Build

```sh
docker build -t openclaw-image:test openclaw/
docker run --rm --entrypoint bash openclaw-image:test -c 'openclaw --version; composio --version; sops --version'
```
