#!/bin/bash
set -e

# Define state and workspace directories
STATE_DIR="${OPENCLAW_STATE_DIR:-/app/state}"
WORKSPACE_DIR="/app/workspace"

# Ensure directories exist
mkdir -p "$STATE_DIR"
mkdir -p "$STATE_DIR/skills"
mkdir -p "$WORKSPACE_DIR"

# Write the .env file for OpenClaw to pick up environment variables
echo "Writing environment variables to $STATE_DIR/.env..."
cat << EOF > "$STATE_DIR/.env"
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
OLLAMA_MODEL=${OLLAMA_MODEL:-llama3:8b}
EOF

# Initialize openclaw.json configuration if it does not exist
if [ ! -f "$STATE_DIR/openclaw.json" ]; then
  if [ -f "/app/openclaw.json" ]; then
    echo "Copying committed openclaw.json to $STATE_DIR/openclaw.json..."
    cp /app/openclaw.json "$STATE_DIR/openclaw.json"
  else
    echo "Initializing default openclaw.json configuration..."
    cat << EOF > "$STATE_DIR/openclaw.json"
{
  "agents": {
    "defaults": {
      "workspace": "$WORKSPACE_DIR",
      "model": {
        "primary": "ollama/${OLLAMA_MODEL:-llama3:8b}"
      }
    },
    "list": [
      {
        "id": "main",
        "identity": {
          "name": "Molty",
          "theme": "helpful learning assistant",
          "emoji": "🦞"
        }
      }
    ]
  },
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "http://ollama:11434",
        "apiKey": "ollama-local"
      }
    }
  },
  "plugins": {
    "entries": {
      "telegram": {
        "enabled": true,
        "package": "@openclaw/plugin-telegram",
        "config": {
          "botToken": "\${env.TELEGRAM_BOT_TOKEN}"
        }
      }
    }
  }
}
EOF
  fi
fi

# Copy the static cron jobs config if not present
if [ ! -f "$STATE_DIR/cron/jobs.json" ]; then
  echo "Initializing static cron jobs.json..."
  mkdir -p "$STATE_DIR/cron"
  if [ -f "/app/state-src/cron/jobs.json" ]; then
    cp /app/state-src/cron/jobs.json "$STATE_DIR/cron/jobs.json"
  fi
fi

# Copy the static agents Standing Order config if not present
if [ ! -f "$WORKSPACE_DIR/AGENTS.md" ]; then
  echo "Initializing static workspace AGENTS.md..."
  if [ -f "/app/workspace-src/AGENTS.md" ]; then
    cp /app/workspace-src/AGENTS.md "$WORKSPACE_DIR/AGENTS.md"
  fi
fi

# Copy the skills to the state directory so they are registered in OpenClaw
echo "Copying skills from workspace..."
if [ -d "/app/skills-src" ]; then
  cp -r /app/skills-src/* "$STATE_DIR/skills/"
fi

# Install the telegram plugin if not already installed
echo "Checking telegram plugin installation..."
openclaw plugins install @openclaw/plugin-telegram || true

# Register standing orders for user onboarding
echo "Registering user onboarding standing order..."
openclaw standing-orders add \
  --name "trigger-user-onboarding" \
  --if "memory.user_profile_{{user.id}} does not exist" \
  --run-skill "user-onboarding" || true

# Register cron job for nightly tech briefs (9 PM in the user's timezone)
echo "Registering daily tech brief cron job..."
openclaw cron add \
  --name "nightly-tech-brief" \
  --cron "0 21 * * *" \
  --tz "{{user_profile.timezone}}" \
  --session isolated \
  --message "Run the daily-quiz skill for the primary user. Use their stored preferences to generate and send the daily brief to them on Telegram." \
  --announce \
  --channel telegram || true

# Run the OpenClaw gateway
echo "Starting OpenClaw gateway..."
exec openclaw gateway start
