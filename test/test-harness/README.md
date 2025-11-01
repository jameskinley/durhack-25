## Durhack • Test Harness (React + Vite + Tailwind)

This app helps exercise the Supabase Edge functions from a simple, flat UI:

- Get user by name
- If no user, fetch tags and create a user with selected preferences
- Pick two locations on a map (lat/lng)

### Setup

1) Install deps

```bash
npm install
```

2) Configure the functions URL

Copy `.env.example` to `.env.local` and set `VITE_FUNCTIONS_URL`.

Examples:

```ini
# Local Supabase
VITE_FUNCTIONS_URL=http://localhost:54321/functions/v1

# Hosted Supabase
# VITE_FUNCTIONS_URL=https://<project-ref>.functions.supabase.co
```

3) Run

```bash
npm run dev
```

Open the app and:

1. Enter a name, click “Get user”.
2. If the user doesn’t exist, tags will load; select some and click “Create user”.
3. Use the map to pick two coordinates (click to add markers, drag to adjust).

