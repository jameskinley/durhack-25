import { supabase } from './supabase';

export type GetUserResponse = { id?: string; message?: string };
export type GetTagsResponse = { tags: string[] };

export async function getUserByName(name: string): Promise<GetUserResponse> {
  // Use POST body for portability across gateways
  const post = await supabase.functions.invoke('get-user', {
    body: { name }
  });
  if (post.error) throw post.error;
  return (post.data as GetUserResponse) ?? {};
}

export async function createUser(name: string, preferences: string[]): Promise<{ ok: boolean }> {
  const resp = await supabase.functions.invoke('create-user', {
    body: { name, preferences }
  });
  if (resp.error) throw resp.error;
  return { ok: true };
}

export async function getAllTags(): Promise<string[]> {
  try {
    const { data, error } = await supabase.functions.invoke('get-tags');
    if (error) throw error;
    const g = (data as GetTagsResponse | undefined)?.tags ?? [];
    if (g.length > 0) return g;
  } catch {
    // ignore and fall back
  }
  return ['rock', 'pop', 'reggae', '60s', 'upbeat', 'jazz', 'electronic', 'indie'];
}
