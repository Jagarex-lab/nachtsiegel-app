# syntax=docker/dockerfile:1
FROM node:24.13.0-bookworm-slim
WORKDIR /app
COPY --chown=node:node package.json package-lock.json ./
# Optional build secret for a managed environment's TLS-inspecting proxy CA.
RUN --mount=type=secret,id=proxy_ca \
    if [ -f /run/secrets/proxy_ca ]; then \
      NODE_EXTRA_CA_CERTS=/run/secrets/proxy_ca npm ci --strict-ssl=true; \
    else npm ci --strict-ssl=true; fi
COPY --chown=node:node src ./src
COPY --chown=node:node migrations ./migrations
RUN mkdir -p /app/var && chown node:node /app/var
USER node
ENV HOST=0.0.0.0 PORT=8787 LOCAL_CONTAINER=1 DB_PATH=/app/var/orafold.sqlite
EXPOSE 8787
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8787/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "--import", "tsx", "src/main.ts"]
