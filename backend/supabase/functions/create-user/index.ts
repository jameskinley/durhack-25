import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { CuratePlaylistRequest } from "../_shared/structs.ts";
import handleCorsPreflight from "../_shared/cors.ts";

console.info('server started');

Deno.serve(async (req: Request) => {
  const { userId, points, duration }: CuratePlaylistRequest = await req.json();

  if(req.method === 'OPTIONS') {
    return handleCorsPreflight(req) as Response;
  }

  if(req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  return new Response(
    JSON.stringify({ message: `User ${userId} created successfully.` }),
    { headers: { 'Content-Type': 'application/json', 'Connection': 'keep-alive' }}
  );
});