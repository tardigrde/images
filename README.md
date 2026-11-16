# opencode-image

Container image for an [opencode](https://github.com/anomalyco/opencode)
server on a small arm64 k3s node.

- Debian `trixie-slim` (glibc), `opencode`, `git`, `gh`, `mise`, `ripgrep`,
  `curl`, `jq`. Runs as user `opencode` (uid 1000).
- `HOME` is `/workspace`. Mount a volume there: repos, opencode data, mise
  toolchains and caches survive restarts.
- Default command: `opencode serve --hostname 0.0.0.0 --port 4096`.
- Image: `ghcr.io/tardigrde/opencode-image:<opencode version>` (also
  `:latest` and `:<version>-<git sha>`). Built for `linux/arm64` by GitHub
  Actions on every push to `main`.

Nothing private goes into this image. Tokens and repos come in at runtime.

## Update a version

Edit the `ARG` lines in `Dockerfile` (version and sha256 per arch). Get the
sha256 from the release asset `digest`:

```sh
gh api repos/anomalyco/opencode/releases/latest \
  -q '.assets[] | select(.name|test("^opencode-linux-(arm64|x64).tar.gz$")) | "\(.name) \(.digest)"'
```

Same for `cli/cli` (gh) and `jdx/mise`. Dependabot updates the base image and
the actions.

## Not in the image yet

Chromium system libraries for Playwright. Add them when the browser is needed.

## Local test (amd64 laptop)

```sh
docker build -t opencode-image:test .
docker run --rm opencode-image:test --version
```
