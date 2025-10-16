# home-assistant
# Home Assistant Umbrella (Elixir + Phoenix LiveView)

This repo contains an Elixir umbrella with:

- apps/ui — Phoenix + LiveView touchscreen UI
- apps/core — Core business logic (OpenAI, Home Assistant, timers)

Phoenix is configured to run at http://0.0.0.0:4000 and mounts a `HomeLive` at `/` with a mobile‑friendly layout featuring a large mic button and chat bubbles.

## Quickstart

1) Install toolchain via `asdf`:

```bash
asdf install
```

2) Install dependencies:

```bash
mix deps.get
```

3) Copy environment file and set your values:

```bash
cp .env.example .env
```

4) Run the server:

```bash
iex -S mix phx.server
```

Then open http://0.0.0.0:4000

## Apps

- `apps/ui`: Phoenix + LiveView app (Tailwind + esbuild assets). Binds `0.0.0.0:4000`.
- `apps/core`: Library app for OpenAI calls, Home Assistant utilities, and a simple Timers GenServer.

## Environment

Copy `.env.example` to `.env` and set:

- `PHX_SECRET_KEY_BASE` — Phoenix secret
- `LIVE_VIEW_SALT` — LiveView signing salt
- `OPENAI_API_KEY` — OpenAI key
- `OPENAI_REALTIME_MODEL` — Realtime model for Voice Mode (default: gpt-4o-realtime-preview)
- `HA_BASE_URL` — Home Assistant base URL
- `HA_TOKEN` — Long‑lived HA token
- `ALLOWED_ORIGINS` — Comma-separated allowed origins for token issuance (prod)

<!-- Calendar integration removed -->

## Docker Compose (optional)

`docker-compose.yml` includes a basic service mapping port 4000. It expects the `.env` file and will run `mix phx.server` in dev mode.

## Voice Mode (Realtime)

- Enable WebRTC “Voice Mode” with OpenAI Realtime.
- Requirements: Chromium/Chrome (HTTPS or localhost for mic), set `OPENAI_API_KEY`.
- API:
  - `POST /api/voice/token` issues short-lived (1 min), single-use ephemeral tokens (rate-limited 3/min per IP).
  - `GET /api/voice/health` returns `{ok: true, model}`.
- UI: Toggle Audio Path between “Voice Mode” and “Local”. Tap the mic to start/stop a live session. Status shows Idle/Connecting/Listening/Speaking.
- Fallback: if Voice Mode fails, the app suggests falling back to Local STT/TTS.

Manual test
- Start server: `iex -S mix phx.server`
- In the browser: enable Voice Mode in the footer controls.
- Tap the mic (Speak). Say a sentence. You should hear a model reply. Tap Stop to end.
- Wait >60s before using a token to simulate expiry; expect a friendly error and retry prompt.
