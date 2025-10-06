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
- `HA_BASE_URL` — Home Assistant base URL
- `HA_TOKEN` — Long‑lived HA token

## Docker Compose (optional)

`docker-compose.yml` includes a basic service mapping port 4000. It expects the `.env` file and will run `mix phx.server` in dev mode.
