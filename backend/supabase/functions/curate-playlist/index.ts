import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { CuratePlaylistRequest } from "../_shared/structs.ts";
import handleCorsPreflight from "../_shared/cors.ts";
import { scheduleTracks } from "./scheduler.ts";

console.info('server started');

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return handleCorsPreflight(req) as Response;
  }

  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405, headers: corsHeaders() });
  }

  try {
    const { journeyId, points, duration }: CuratePlaylistRequest = await req.json();
    if (!journeyId || !Array.isArray(points) || points.length < 2 || !Number.isFinite(Number(duration))) {
      return new Response(JSON.stringify({ error: 'invalid request payload' }), { status: 400, headers: corsHeaders() });
    }
    const playlist = await scheduleTracks(journeyId, points, duration);
    return new Response(
      JSON.stringify(playlist),
      { headers: { ...corsHeaders(), 'Content-Type': 'application/json', 'Connection': 'keep-alive' } }
    );
  } catch (e) {
    console.error('[curate-playlist] error', e);
    return new Response(JSON.stringify({ error: 'failed to curate' }), { status: 500, headers: corsHeaders() });
  }
});

function corsHeaders(): HeadersInit {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };
}