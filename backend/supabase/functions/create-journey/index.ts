import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import handleCorsPreflight, { corsHeaders } from "../_shared/cors.ts";
import { createJourney } from "./lib.ts";

console.info('[create-journey] server started');

type CreateJourneyRequest = { preferences: string[] };

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return handleCorsPreflight(req) as Response;
  }

  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405, headers: corsHeaders(req) });
  }

  try {
    let { preferences }: CreateJourneyRequest = await req.json();
    preferences = preferences.map(c => c.toLowerCase());
    if (!Array.isArray(preferences)) {
      return new Response(JSON.stringify({ error: 'Invalid payload' }), { status: 400, headers: corsHeaders(req) });
    }
    const result = await createJourney(preferences);
    return new Response(JSON.stringify({ ok: result.ok, id: result.id }), {
      headers: { ...corsHeaders(req), 'Content-Type': 'application/json', 'Connection': 'keep-alive' }
    });
  } catch (e) {
    console.error('[create-journey] error', e);
    return new Response(JSON.stringify({ ok: false }), { status: 500, headers: corsHeaders(req) });
  }
});
