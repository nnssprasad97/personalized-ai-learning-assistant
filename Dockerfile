# Use the official Node.js 20 Alpine image as the base
FROM node:20-alpine

# Install system dependencies (git, bash, curl are required/useful for OpenClaw and plugins)
RUN apk add --no-cache bash git curl openssh-client

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Set up app directory
WORKDIR /app

# Set environment variables
ENV OPENCLAW_STATE_DIR=/app/state
ENV PATH="/usr/local/bin:${PATH}"

# Copy the skills source directory, config files, and entrypoint script
COPY skills /app/skills-src
COPY openclaw.json /app/openclaw.json
COPY state /app/state-src
COPY workspace /app/workspace-src
COPY docker-entrypoint.sh /app/docker-entrypoint.sh

# Make entrypoint script executable and ensure Unix line endings
RUN chmod +x /app/docker-entrypoint.sh && \
    sed -i 's/\r$//' /app/docker-entrypoint.sh

# Expose default OpenClaw Gateway port
EXPOSE 18789

# Set the entrypoint to the startup script
ENTRYPOINT ["/app/docker-entrypoint.sh"]
