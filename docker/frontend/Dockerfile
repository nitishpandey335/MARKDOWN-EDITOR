# ─────────────────────────────────────────────
# Stage 1: Build the React/Vite app
# ─────────────────────────────────────────────
FROM node:20-alpine AS builder

# Set working directory inside the container
WORKDIR /app

# Copy only package files first (better layer caching)
COPY frontend/package*.json ./

# Install all dependencies (including devDeps needed for build)
RUN npm ci

# Copy the rest of the frontend source code
COPY frontend/ .

# Build the production bundle (outputs to /app/dist)
RUN npm run build

# ─────────────────────────────────────────────
# Stage 2: Serve with Nginx (lightweight)
# ─────────────────────────────────────────────
FROM nginx:1.25-alpine

# Remove default nginx static files
RUN rm -rf /usr/share/nginx/html/*

# Copy built files from Stage 1
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy custom nginx config (handles React Router SPA routing)
COPY docker/frontend/nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx in foreground (required for Docker)
CMD ["nginx", "-g", "daemon off;"]
