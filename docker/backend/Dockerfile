# ─────────────────────────────────────────────
# Stage 1: Install production dependencies
# ─────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

# Copy package files
COPY backend/package*.json ./

# Remove the local file reference that breaks Docker build
# "react-md-editor-monorepo": "file:.." is only for local dev
RUN node -e "
  const fs = require('fs');
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  delete pkg.dependencies['react-md-editor-monorepo'];
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
"

# Install production dependencies
RUN npm install --omit=dev --legacy-peer-deps

# ─────────────────────────────────────────────
# Stage 2: Final runtime image
# ─────────────────────────────────────────────
FROM node:20-alpine

# Non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy node_modules from Stage 1
COPY --from=deps /app/node_modules ./node_modules

# Copy backend source code
COPY backend/ .

# Change ownership
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:5000/api/health || exit 1

CMD ["node", "server.js"]
