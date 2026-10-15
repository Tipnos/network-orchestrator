# Debian (glibc) rather than Alpine: fewer problems with crates linking C libs.
FROM rust:1-bookworm

ARG USERNAME=dev
# Match the host UID so files written in .worktrees are owned by you.
ARG UID=1000

# Node is only needed to run Claude Code.
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates ripgrep jq less \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# NATS CLI, from the release .deb.
ARG NATSCLI_VERSION=0.5.0
ARG NATSCLI_SHA256_amd64=d2f4c8c59da82c913a8e04c59975336f5f5e693a54a5c43d763aee32997a79ee
ARG NATSCLI_SHA256_arm64=53898277826ffbea1ce72204c183e073b7fe77936d05945a46f47beec351b9a8
RUN arch="$(dpkg --print-architecture)" \
    && case "$arch" in \
         amd64) sha="${NATSCLI_SHA256_amd64}" ;; \
         arm64) sha="${NATSCLI_SHA256_arm64}" ;; \
         *) echo "unsupported arch $arch" >&2; exit 1 ;; \
       esac \
    && curl -fsSLo /tmp/nats.deb \
      https://github.com/nats-io/natscli/releases/download/v${NATSCLI_VERSION}/nats-${NATSCLI_VERSION}-${arch}.deb \
    && echo "${sha}  /tmp/nats.deb" | sha256sum -c - \
    && dpkg -i /tmp/nats.deb \
    && rm /tmp/nats.deb

# Git >= 2.48 is required to read relative worktree paths. Debian ships older,
# so build it from the release tarball (build deps are in the base image).
ARG GIT_VERSION=2.55.0
ARG GIT_SHA256=457fdb04dc8728e007d4688695e6912e6f680727920f2a40bf11eacc17505357
RUN curl -fsSLo /tmp/git.tar.xz \
      https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.xz \
    && echo "${GIT_SHA256}  /tmp/git.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/git.tar.xz -C /tmp \
    && make -C /tmp/git-${GIT_VERSION} -j"$(nproc)" \
         prefix=/usr/local NO_GETTEXT=1 NO_TCLTK=1 install >/dev/null \
    && rm -rf /tmp/git*

# Directories are created up front so named volumes mounted on them inherit
# the right owner.
RUN useradd --create-home --uid ${UID} --shell /bin/bash ${USERNAME} \
    && mkdir -p /home/${USERNAME}/target /home/${USERNAME}/.claude /workspace \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME} /workspace \
         /usr/local/cargo /usr/local/rustup

ENV CARGO_TARGET_DIR=/home/${USERNAME}/target

USER ${USERNAME}

RUN rustup component add rustfmt clippy rust-analyzer \
    && cargo install just --locked \
    && npm config set prefix /home/${USERNAME}/.npm-global \
    && npm install -g @anthropic-ai/claude-code

ENV PATH="/home/${USERNAME}/.npm-global/bin:${PATH}"
WORKDIR /workspace/.worktrees
