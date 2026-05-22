# Personalized AI Learning Assistant on Telegram with OpenClaw

A personalized Telegram bot powered by OpenClaw that acts as a daily study partner. The assistant learns a user's technical interests and skill level during onboarding, searches the web daily for tailored content, and delivers a curated set of interview questions and technical insights every evening at 9:00 PM local time.

## Project Background & Architecture

OpenClaw is an open-source, self-hosted gateway connecting language models, chat channels, and agent tools. This project builds a complete personalized learning pipeline:
1. **User Interaction (Telegram):** The user connects via a Telegram bot created with `@BotFather`.
2. **Onboarding Skill:** Triggered on the first message if no profile exists, interviewing the user sequentially about their domains, experience level, goals, and timezone, and saving this to OpenClaw's persistent memory.
3. **Daily Quiz Skill:** Fired every night at 9:00 PM in the user's timezone. It retrieves the user's profile, conducts a web search using the `web_search` tool for fresh articles in the user's domains, synthesizes 3-5 technical tidbits, generates exactly 5 difficulty-appropriate interview questions, and delivers them via Telegram.
4. **Automation & State:** Handled natively by the OpenClaw cron scheduler and persistent memory store.
5. **Containerization:** Built using Docker and orchestrated with Docker Compose to deploy the OpenClaw gateway alongside a local Ollama model service.

---

## Onboarding Trigger Rationale

We implement the onboarding flow using an OpenClaw **Standing Order** rule rather than a Webhook.

### Rationale
- **Self-Hosted Simplicity:** Webhooks require exposing the local OpenClaw gateway port to the public internet using tools like `ngrok` or configuring domain SSL certificates. Standing Orders run entirely within OpenClaw's internal agent loop.
- **Privacy & Offline Resilience:** Since Standing Orders run locally and check state rules (`memory.user_profile_{{user.id}} does not exist`), they do not rely on external gateway webhook routers, making the setup much more robust and private.
- **State-Driven Triggering:** Standing Orders evaluate conditional logic against the OpenClaw memory store. This ensures the onboarding workflow triggers reliably for any new user who sends a message to the bot for the first time, without extra infrastructure.

---

## Configuration Snippet: `openclaw.json`

Below is the structured configuration for OpenClaw. Sensitive variables like the bot token are securely resolved from environment variables using the `\${env.VARIABLE_NAME}` syntax.

```json
{
  "agents": {
    "defaults": {
      "workspace": "/app/workspace",
      "model": {
        "primary": "ollama/llama3:8b"
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
          "botToken": "${env.TELEGRAM_BOT_TOKEN}"
        }
      }
    }
  }
}
```

---

## Deployment Configuration & Startup Lifecycle

This project is configured with pre-defined static settings that make manual setup unnecessary when deploying.

### Configuration Files
- **`openclaw.json`**: Located at the root. Configures the OpenClaw Gateway agents, Ollama model providers, and the Telegram messaging channel.
- **`state/cron/jobs.json`**: Located in the state directory. Pre-defines the `nightly-tech-brief` cron schedule to run the daily brief at 9:00 PM local time.
- **`workspace/AGENTS.md`**: Located in the workspace directory. Pre-defines the Standing Order program for user onboarding.

### Startup Lifecycle: `docker-entrypoint.sh`
The container initialization is managed automatically by [docker-entrypoint.sh](file:///c:/Users/nnssp/Desktop/personalized-ai-learning-assistant/docker-entrypoint.sh):
1. **Directory Preparation:** Creates the state (`/app/state`) and workspace (`/app/workspace`) folders inside the container.
2. **Environment Export:** Writes the runtime environment variables (`TELEGRAM_BOT_TOKEN`, `OLLAMA_MODEL`) to `/app/state/.env` for OpenClaw.
3. **Gateway Configuration:** Copies the committed `openclaw.json` config from the root of the project to `/app/state/openclaw.json`.
4. **Static Schedules & Orders Initialization:**
   - Copies `state/cron/jobs.json` to the runtime state directory if missing.
   - Copies `workspace/AGENTS.md` to the runtime workspace directory if missing.
5. **Skill Deployment:** Copies the onboarding and daily-quiz skills into `/app/state/skills/` to register them.
6. **Plugin Verification:** Ensures `@openclaw/plugin-telegram` is installed.
7. **Gateway Bootstrap:** Launches the gateway daemon (`openclaw gateway start`) to start serving the Telegram bot.

---

## Setup and Deployment Instructions

### Prerequisites
- Docker and Docker Compose installed on your system.
- A Telegram account.

### Step 1: Create a Telegram Bot
1. Search for `@BotFather` in Telegram and open a chat.
2. Send `/newbot` and follow the prompts to name your bot and choose a username.
3. Save the HTTP API Token provided (e.g., `123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ`).

### Step 2: Configure Environment Variables
1. Clone this repository or enter the project directory.
2. Copy the example env file:
   ```bash
   cp .env.example .env
   ```
3. Open `.env` and insert your Telegram bot token:
   ```env
   TELEGRAM_BOT_TOKEN=YOUR_TELEGRAM_BOT_TOKEN
   OLLAMA_MODEL=llama3:8b
   ```

### Step 3: Run the Application
Start the containerized services using Docker Compose:
```bash
docker compose up -d --build
```
This command starts:
1. **Ollama Service (`ollama-service`):** Serving the local LLM.
2. **OpenClaw Gateway (`openclaw-gateway`):** Running the OpenClaw platform, loading skills, installing the Telegram plugin, and scheduling the jobs.

### Step 4: Download the LLM inside Ollama
Inside the Ollama container, pull the model defined in your `.env` (by default `llama3:8b`):
```bash
docker exec -it ollama-service ollama pull llama3:8b
```
*(If you have a slower internet connection or hardware, you can change `OLLAMA_MODEL` in your `.env` to `gemma:2b` and pull `gemma:2b` instead).*

---

## Testing & Verification

### 1. Test User Onboarding
1. Open Telegram, search for your bot's username, and start a chat.
2. Send a greeting message (e.g., "Hello").
3. The bot will automatically trigger the onboarding skill, asking you sequentially for:
   - Technical domains.
   - Experience level.
   - Learning goals.
   - Timezone.
4. Respond to each prompt. Once complete, the bot will save your profile to persistent memory.

### 2. Verify Saved Memory
You can inspect the agent's persistent memory to confirm your profile was saved matching the schema:
```bash
docker exec -it openclaw-gateway openclaw memory get "user_profile_<YOUR_TELEGRAM_USER_ID>"
```
Expected stored format:
```json
{
  "domains": ["Go", "Distributed Systems"],
  "level": "mid-level",
  "goals": ["staying up-to-date", "deep-diving"],
  "timezone": "America/New_York"
}
```

### 3. Test Daily Quiz Generation Manually
You do not have to wait until 9:00 PM to verify the quiz works. Trigger the nightly brief job manually:
```bash
docker exec -it openclaw-gateway openclaw cron trigger "nightly-tech-brief"
```
You will receive the structured markdown daily tech brief message on Telegram within a few moments!
