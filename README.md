# durhack-25
DurHack 25 Repo

## Local development

### Frontend test harness

The React/Vite harness lives in `test/test-harness`.

- Install deps and run dev server
	- `npm install`
	- `npm run dev`
- Build
	- `npm run build`

Environment:

- Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in `test/test-harness/.env` (create it if missing).

### Supabase Edge functions

Functions live under `backend/supabase/functions`.

For local serving with the Supabase CLI you must provide two env vars:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE` (service role key)

Steps:

1) Copy `backend/.env.example` to `backend/.env` and fill in values from your project (Dashboard → Project Settings → API).

2) Start the functions locally from the `backend` folder:

```bash
npx supabase functions serve --no-verify-jwt --env-file ./.env
```

Notes:

- The service role is required for admin operations performed by `create-journey` (inserting rows and upserting candidates). In production, these are securely provided to the Edge runtime.
- If these env vars are missing, the function will return HTTP 500 with a clear error log instead of crashing.

