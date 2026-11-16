# opencode server image for the home-cluster Pi (k3s, arm64).
# Debian slim (glibc), opencode, git, gh, mise, ripgrep. Non-root.
# Toolchains (mise) and browsers (Playwright) install at runtime into /workspace.
FROM debian:trixie-slim@sha256:a72b4433de1cf7d6bae0c4cee74d0547f58601a643b3375f070c51600d63b6b2

ARG TARGETARCH
ARG OPENCODE_VERSION=1.19.5
ARG OPENCODE_SHA256_arm64=fae5be262d693b7c5e562856cc473e59e741772936db0c0600ac0d5ed5bd088b
ARG OPENCODE_SHA256_amd64=588310a336fa3b9df36b3f0225b26f679d453efaad0cf3d66c3651ef3ec1647a
ARG GH_VERSION=2.104.0
ARG GH_SHA256_arm64=cb34cefc6f4e77b90731374a2b737516bb8f3033c6ca46aa949e5344f68069e3
ARG GH_SHA256_amd64=98cb101ad87dbbd3f6b2f2bfcbd43197ccd07643140121d8a9cfaa91eadbc24e
ARG MISE_VERSION=2026.11.9
ARG MISE_SHA256_arm64=b8dd05af6447cee933928664982a8cb2fa646e6951cfc8539db23ce2554a7b04
ARG MISE_SHA256_amd64=f13f3e5ec88807e0161669b3aa07a91d84478cdf1e95b5b92b63f85a25d42395

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git jq less openssh-client procps ripgrep \
      tini unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in \
      arm64) oc=arm64; ghx=arm64; mx=arm64; \
             oc_sum=$OPENCODE_SHA256_arm64; gh_sum=$GH_SHA256_arm64; m_sum=$MISE_SHA256_arm64 ;; \
      amd64) oc=x64;   ghx=amd64; mx=x64; \
             oc_sum=$OPENCODE_SHA256_amd64; gh_sum=$GH_SHA256_amd64; m_sum=$MISE_SHA256_amd64 ;; \
      *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
    esac \
 && cd /tmp \
 && curl -fsSLo oc.tgz "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${oc}.tar.gz" \
 && echo "${oc_sum}  oc.tgz" | sha256sum -c - \
 && tar -xzf oc.tgz && install -m 0755 opencode /usr/local/bin/opencode \
 && curl -fsSLo gh.tgz "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ghx}.tar.gz" \
 && echo "${gh_sum}  gh.tgz" | sha256sum -c - \
 && tar -xzf gh.tgz && install -m 0755 "gh_${GH_VERSION}_linux_${ghx}/bin/gh" /usr/local/bin/gh \
 && curl -fsSLo mise "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/mise-v${MISE_VERSION}-linux-${mx}" \
 && echo "${m_sum}  mise" | sha256sum -c - \
 && install -m 0755 mise /usr/local/bin/mise \
 && rm -rf /tmp/*

# HOME is the workspace volume: repos, opencode data, mise, caches survive restarts.
RUN useradd --uid 1000 --user-group --home-dir /workspace --no-create-home --shell /bin/bash opencode \
 && mkdir -p /workspace && chown opencode:opencode /workspace

ENV HOME=/workspace \
    PATH=/workspace/.local/share/mise/shims:/workspace/.local/bin:/usr/local/bin:/usr/bin:/bin

USER 1000:1000
WORKDIR /workspace
EXPOSE 4096
ENTRYPOINT ["/usr/bin/tini", "--", "opencode"]
CMD ["serve", "--hostname", "0.0.0.0", "--port", "4096"]
