FROM node:24-bookworm-slim
ARG DSH_VERSION=0.2.1-rc.5
ARG PNPM_VERSION=11.28.5
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git curl python3 python3-venv python3-pip \
    build-essential ripgrep jq bubblewrap procps \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g pnpm@${PNPM_VERSION} @deepseek-ai/dsh@${DSH_VERSION} \
    && npm cache clean --force
ENV HOME=/home/node DSH_HOME=/home/node/.dsh \
    DSH_TELEMETRY_MODE=DISABLED DSH_TELEMETRY_DISABLED=1 \
    NPM_CONFIG_PREFIX=/home/node/.local PATH=/home/node/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN mkdir -p /workspace /home/node/.dsh /home/node/.local \
    && chown -R node:node /workspace /home/node
COPY --chmod=755 start.sh /usr/local/bin/start-harness
COPY container.patch.yml /etc/dsh-container.patch.yml
USER 1000:1000
WORKDIR /workspace
RUN dsh web --dump-default-config > /home/node/.dsh/default-web-config.yml
EXPOSE 3080
CMD ["/usr/local/bin/start-harness"]

