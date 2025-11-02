import { supabase } from './supabase';

export type GetUserResponse = { id?: string; message?: string };
export type GetTagsResponse = { tags: string[] };
export type PlaylistTrack = { track: string; artist: string; type: 'track' | 'bio' };

export async function getUserByName(name: string): Promise<GetUserResponse> {
  // Use POST body for portability across gateways
  const post = await supabase.functions.invoke('get-user', {
    body: { name }
  });
  if (post.error) throw post.error;
  return (post.data as GetUserResponse) ?? {};
}

export async function createJourney(name: string, preferences: string[]): Promise<{ ok: boolean; id?: string }> {
  const resp = await supabase.functions.invoke('create-journey', {
    body: { name, preferences }
  });
  if (resp.error) throw resp.error;
  const data = resp.data as { ok?: boolean; id?: string } | undefined;
  return { ok: Boolean(data?.ok ?? true), id: data?.id };
}

// Backward-compat alias (optional):
export const createUser = createJourney;

export async function getAllTags(): Promise<string[]> {
  try {
    const { data, error } = await supabase.functions.invoke('get-tags');
    if (error) throw error;
    const g = (data as GetTagsResponse | undefined)?.tags ?? [];
    if (g.length > 0) return g;
  } catch {
    // ignore and fall back
  }
  return ['rock', 'pop', 'reggae', '60s', 'upbeat', 'jazz', 'electronic', 'indie', 'alternative'];
}

export async function curatePlaylist(params: {
  journeyId: string;
  points: { x: number; y: number }[];
  durationSeconds: number;
}): Promise<PlaylistTrack[]> {
  const { journeyId, points, durationSeconds } = params;
  const resp = await supabase.functions.invoke('curate-playlist', {
    body: { journeyId, points, duration: durationSeconds }
  });
  if (resp.error) throw resp.error;
  return (resp.data as PlaylistTrack[]) ?? [];
}
