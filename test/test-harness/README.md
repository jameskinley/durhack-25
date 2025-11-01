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

2) Configure Supabase client

Copy `.env.example` to `.env.local` and set:

```ini
VITE_SUPABASE_URL=YOUR_SUPABASE_URL
VITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

For supabase CLI local dev, URL is typically `http://localhost:54321` and the anon key can be read from the CLI env or dashboard.

3) Run

```bash
npm run dev
```

Open the app and:

1. Enter a name, click “Get user”.
2. If the user doesn’t exist, tags will load; select some and click “Create user”.
3. Use the map to pick two coordinates (click to add markers, drag to adjust).

