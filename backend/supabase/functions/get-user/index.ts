import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import handleCorsPreflight from "../_shared/cors.ts";
import { findUserById, findUserByName } from "./lib.ts";

console.info('[get-user] server started');

type GetUserRequest = { id?: string; name?: string };

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return handleCorsPreflight(req) as Response;
  }

  if (req.method !== 'GET' && req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  let id: string | undefined;
  let name: string | undefined;

  try {
    if (req.method === 'GET') {
      const url = new URL(req.url);
      id = url.searchParams.get('id') ?? undefined;
      name = url.searchParams.get('name') ?? undefined;
    } else {
      const body = (await req.json()) as GetUserRequest;
      id = body?.id;
      name = body?.name;
    }
  } catch (_e) {
    // ignore body parse errors; continue as undefined params
  }

  let user = null;
  if (id) {
    user = await findUserById(id);
  } else if (name) {
    user = await findUserByName(name);
  }

  const headers = { 'Content-Type': 'application/json', 'Connection': 'keep-alive' };

  if (user) {
    return new Response(JSON.stringify({ id: user.id }), { headers });
  }

  return new Response(JSON.stringify({ message: 'no user' }), { headers });
});
