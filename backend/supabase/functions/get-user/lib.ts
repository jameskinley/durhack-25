import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.36.0';

// Keep local editors happy; Deno provides this at runtime on Supabase Edge
declare const Deno: { env: { get: (key: string) => string | undefined } };

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE')!;

export const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, {
  auth: { persistSession: false }
});

const USERS_TABLE = 'users';

export type UserRow = {
  id: string;
  name?: string;
};

export async function findUserById(id: string): Promise<UserRow | null> {
  const { data, error } = await supabase
    .from(USERS_TABLE)
    .select('id, name')
    .eq('id', id)
    .maybeSingle<UserRow>();

  if (error) {
    console.error('[get-user/lib] findUserById error', error);
    return null;
  }
  return data ?? null;
}

export async function findUserByName(name: string): Promise<UserRow | null> {
  const { data, error } = await supabase
    .from(USERS_TABLE)
    .select('id, name')
    .eq('name', name)
    .maybeSingle<UserRow>();

  if (error) {
    console.error('[get-user/lib] findUserByName error', error);
    return null;
  }
  return data ?? null;
}
