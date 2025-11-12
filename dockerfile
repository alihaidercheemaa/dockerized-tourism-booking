# Multi-stage Dockerfile for Next.js (app dir)
# Uses Node 20 on Alpine

FROM node:20-alpine AS deps
WORKDIR /app

# Install basic build tools
RUN apk add --no-cache python3 make g++

# Copy package metadata and install dependencies
COPY package.json package-lock.json* ./
# If there's a lockfile, prefer npm ci; otherwise fallback to npm install
RUN if [ -f package-lock.json ]; then npm ci --legacy-peer-deps --no-audit --progress=false; else npm install --legacy-peer-deps --no-audit --progress=false; fi

FROM node:20-alpine AS builder
WORKDIR /app

# Copy source
COPY . .

# Copy node_modules from deps to speed up install
COPY --from=deps /app/node_modules ./node_modules

# Provide safe build-time defaults for env vars so `next build` won't fail
# These can be overridden with --build-arg when building the image.
ARG UPLOADTHING_TOKEN=""
ARG API_URL=
ARG AUTH_SECRET=""

ENV UPLOADTHING_TOKEN=${UPLOADTHING_TOKEN}
ENV API_URL=${API_URL}
ENV AUTH_SECRET=${AUTH_SECRET}

# Build the Next.js app
RUN npm run build

# Production image
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=5010

# Expose the port the app will run on (matches package.json start script)
EXPOSE 5010

# Copy only the necessary files from builder
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

# If you use environment variables in production, set them at runtime via -e or --env-file

# Start the app with the project's start script (it uses port 5010)
CMD ["npm","start"]
