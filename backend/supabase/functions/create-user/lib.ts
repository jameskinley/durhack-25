import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.36.0';
// Keep local editors happy; Deno provides this at runtime on Supabase Edge
declare const Deno: { env: { get: (key: string) => string | undefined } };

function getClient(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE');
  if (!url || !serviceKey) {
    console.error('[create-user/lib] Missing required env vars', {
      hasUrl: Boolean(url),
      hasServiceRole: Boolean(serviceKey)
    });
    throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE');
  }
  return createClient(url, serviceKey, { auth: { persistSession: false } });
}

// Table names (adjust to your schema if different)
const USERS_TABLE = 'users';
const TRACKS_TABLE = 'tracks';
const USER_CANDIDATE_TRACKS_TABLE = 'user_candidate_tracks';

// Tuning knobs (can be overridden via env vars)
const MAX_SYMM_DIFF = Number(Deno.env.get('MAX_TAG_DIFF') ?? 2); // max symmetric-diff allowed
const MAX_CANDIDATES = Number(Deno.env.get('MAX_CANDIDATES') ?? 200); // cap for stored candidates

type UUID = string;

type UserRow = {
  id: UUID;
  name?: string;
  preferences: string[];
};

type TrackRow = {
  id: UUID;
  title?: string;
  tags: string[];
};

/**
 * Calculates candidate tracks for a user.
 * @param userId the ID of the user
 * @returns true if calculation was successful, false otherwise
 */
async function calculateCandidateTracks(userId: string): Promise<boolean> {
  // 1) Load user preferences
  const supabase = getClient();
  const { data: user, error: userErr } = await supabase
    .from(USERS_TABLE)
    .select('id, preferences')
    .eq('id', userId)
    .single<UserRow>();

  if (userErr) {
    console.error('[calculateCandidateTracks] Failed to fetch user', userErr);
    return false;
  }

  const preferences = (user?.preferences ?? []).filter(Boolean);
  if (preferences.length === 0) {
    // No preferences -> nothing to calculate; treat as success
    return true;
  }

  // 2) Fetch candidate tracks. For maximum compatibility, fetch all and filter in-memory.
  // If your schema is large, consider creating an index on tracks.tags (text[]) and
  // filtering in SQL first using array operators (e.g., tags && prefs) to pre-restrict.
  const { data: tracks, error: tracksErr } = await supabase
    .from(TRACKS_TABLE)
    .select('id, tags');

  if (tracksErr) {
    console.error('[calculateCandidateTracks] Failed to fetch tracks', tracksErr);
    return false;
  }

  const prefSet: Set<string> = new Set<string>(preferences);

  const symmDiffSize = (a: Set<string>, b: Set<string>): number => {
    let inter = 0;
    for (const t of a) if (b.has(t)) inter++;
    // |A Δ B| = |A| + |B| - 2|A∩B|
    return a.size + b.size - 2 * inter;
  };

  const intersectionSize = (a: Set<string>, b: Set<string>): number => {
    let inter = 0;
    for (const t of a) if (b.has(t)) inter++;
    return inter;
  };

  // 3) Score and filter by symmetric difference (exact matches first, then small differences)
  type Scored = { trackId: UUID; diff: number; inter: number; size: number };
  const trackRows: TrackRow[] = ((tracks ?? []) as unknown as TrackRow[]);

  const scored: Scored[] = trackRows
    .filter((tr: TrackRow) => Array.isArray(tr.tags))
    .map((tr: TrackRow) => {
      const tagSet: Set<string> = new Set<string>(tr.tags);
      const diff = symmDiffSize(prefSet, tagSet);
      const inter = intersectionSize(prefSet, tagSet);
      return { trackId: tr.id, diff, inter, size: tagSet.size } as Scored;
    })
    // Keep only those within the allowed difference budget
    .filter((x: Scored) => x.diff <= MAX_SYMM_DIFF)
    // Sort: exact matches (diff=0) first, then increasing diff, then larger intersection,
    // then fewer extra tags (smaller size), finally by id for stability
    .sort((a: Scored, b: Scored) =>
      (a.diff - b.diff)
      || (b.inter - a.inter)
      || (a.size - b.size)
      || a.trackId.localeCompare(b.trackId)
    )
    .slice(0, MAX_CANDIDATES);

  // 4) Store candidates in junction table with rank/score
  if (scored.length === 0) return true; // nothing to write, but not an error

  const payload = scored.map((s: Scored, idx: number) => ({
    user_id: userId,
    track_id: s.trackId,
    rank: idx + 1,
    // Higher is better; transform so exact matches get a big boost
    score: (MAX_SYMM_DIFF - s.diff) * 100 + s.inter * 10 - s.size,
  }));

  const { error: upsertErr } = await supabase
    .from(USER_CANDIDATE_TRACKS_TABLE)
    .upsert(payload, { onConflict: 'user_id,track_id' });

  if (upsertErr) {
    console.error('[calculateCandidateTracks] Failed to upsert candidates', upsertErr);
    return false;
  }

  return true;
}

/**
 * Creates a new user and calculates their candidate tracks.
 * @param userId 
 * @returns 
 */
export async function createUser(name: string, preferences: string[]): Promise<boolean> {
  const supabase = getClient();
  // 1) Create the user with supplied preferences
  const { data: inserted, error } = await supabase
      .from(USERS_TABLE)
      .insert([{ name, preferences }])
      .select('id')
      .single<UserRow>();

    if (error || !inserted?.id) {
      console.error('[createUser] Failed to create user', error);
      return false;
    }

    // 2) Precompute candidate tracks for this user
    const ok = await calculateCandidateTracks(inserted.id);
    return ok;
}