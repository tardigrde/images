# opencode-image

Misc container images for [opencode](https://github.com/anomalyco/opencode),
one per use case. All images are Debian `trixie-slim` (glibc) with `git`, `gh`,
`ripgrep`, `curl`, and `jq`. All build for `linux/amd64` and `linux/arm64`.

Nothing private goes into these images. Tokens and repos come in at runtime.

| Variant | Image | For | User | Entrypoint |
| --- | --- | --- | --- | --- |
| `server` | `ghcr.io/tardigrde/opencode-image` | An opencode server, for example on a small arm64 k3s node | `opencode` (uid 1000) | `opencode` |
| `eval` | `ghcr.io/tardigrde/opencode-image-eval` | Agent evals in containers, for example [Harbor](https://github.com/harbor-framework/harbor) | `root` | none (`bash`) |

Tags for both images: `<opencode version>`, `latest`, and
`<opencode version>-<git sha>`. The version is the opencode CLI inside that
image: 1.x for `server`, 2.x for `eval`.

One `Dockerfile` builds both. A shared `base` stage holds the tools. Each variant
is a stage on top of it, so a new use case is one new stage. The `server` stage is
last, so a plain `docker build .` still gives the server image.

## server

- Also has `mise` and `tini`.
- `HOME` is `/workspace`. Mount a volume there: repos, opencode data, mise
  toolchains and caches survive restarts.
- Default command: `opencode serve --hostname 0.0.0.0 --port 4096`.

```sh
docker build --target server -t opencode-image:test .
docker run --rm opencode-image:test --version
```

## eval

- Runs as root with no opencode entrypoint. Harbor installs its agent and runs
  commands as root.
- The opencode V2 CLI (`@opencode/cli`) is already in
  `/root/.harbor/agents/opencode-v2`, where Harbor's `opencode-v2` agent looks.
  Harbor then skips its own install. In a test, agent setup dropped from about
  146 s to 2 s per trial.
- Use it as the base image of an exported Harbor task suite, for example with
  [agent-skill-eval](https://github.com/tardigrde/agent-skill-eval):

```sh
agent-skill-eval run --backend harbor --harbor-base-image ghcr.io/tardigrde/opencode-image-eval:latest ...
```

```sh
docker build --target eval -t opencode-image-eval:test .
docker run --rm opencode-image-eval:test /root/.harbor/agents/opencode-v2/node_modules/.bin/opencode --version
```

## Build

GitHub Actions builds each variant natively on an amd64 runner and an arm64
runner (no QEMU), pushes each by digest, then joins the two into one multi-arch
tag. Pull requests build and smoke-test both architectures but push nothing.

## Update a version

Edit the `ARG` lines in `Dockerfile`:

- `server`: `OPENCODE_VERSION`, plus the sha256 for each arch. Get the sha256 from
  the release asset `digest`:

  ```sh
  gh api repos/anomalyco/opencode/releases/latest \
    -q '.assets[] | select(.name|test("^opencode-linux-(arm64|x64).tar.gz$")) | "\(.name) \(.digest)"'
  ```

  Same for `cli/cli` (gh) and `jdx/mise`.
- `eval`: `OPENCODE_V2_VERSION`, the npm version of `@opencode/cli`
  (`npm view @opencode/cli version`).

Dependabot (weekly) updates the base image and the actions.

## Add a variant

Add a stage that starts `FROM base AS <name>`. Then add `<name>` to the `variant`
lists in `.github/workflows/build.yml`, and set the smoke test for it.

## Not in the images yet

Chromium system libraries for Playwright. Add them when the browser is needed.
