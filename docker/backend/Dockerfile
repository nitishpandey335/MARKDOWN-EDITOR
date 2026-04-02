# ─────────────────────────────────────────────
# Stage 1: Install production dependencies only
# ─────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

# Copy package files
COPY backend/package*.json ./

# Install only production dependencies (no devDeps like nodemon)
RUN npm ci --omit=dev

# ─────────────────────────────────────────────
# Stage 2: Final runtime image
# ─────────────────────────────────────────────
FROM node:20-alpine

# Create a non-root user for security (never run as root in production)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy installed node_modules from Stage 1
COPY --from=deps /app/node_modules ./node_modules

# Copy backend source code
COPY backend/ .

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose the backend port
EXPOSE 5000

# Health check — Kubernetes will use this to know if the pod is alive
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:5000/api/health || exit 1

# Start the Node.js server
CMD ["node", "server.js"]
