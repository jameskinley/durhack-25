import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.36.0';

// Keep local editors happy; Deno provides this at runtime on Supabase Edge
declare const Deno: { env: { get: (key: string) => string | undefined } };

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE')!;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE) {
  console.error('[create-journey/lib] Missing required env vars', {
    hasUrl: Boolean(SUPABASE_URL),
    hasServiceRole: Boolean(SUPABASE_SERVICE_ROLE)
  });
}
export const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, {
  auth: {
    persistSession: false
  }
});

// Table names (adjust to your schema if different)
const JOURNEYS_TABLE = 'journeys';
const TRACKS_TABLE = 'tracks';
const JOURNEY_CANDIDATE_TRACKS_TABLE = 'journey_candidate_tracks';

// Tuning knobs (can be overridden via env vars)
const MAX_SYMM_DIFF = Number(Deno.env.get('MAX_TAG_DIFF') ?? 2); // max symmetric-diff allowed
const MAX_CANDIDATES = Number(Deno.env.get('MAX_CANDIDATES') ?? 200); // cap for stored candidates

type UUID = string;

type JourneyRow = {
  id: UUID;
  preferences: string[];
};

type TrackRow = {
  id: UUID;
  title?: string;
  tags: string[];
};

/**
 * Calculates candidate tracks for a journey.
 */
async function calculateCandidateTracksForJourney(journeyId: string): Promise<boolean> {
  // 1) Load journey preferences
  const { data: journey, error: journeyErr } = await supabase
    .from(JOURNEYS_TABLE)
    .select('id, preferences')
    .eq('id', journeyId)
    .single<JourneyRow>();

  if (journeyErr) {
    console.error('[calculateCandidateTracksForJourney] Failed to fetch journey', journeyErr);
    return false;
  }

  const preferences = (journey?.preferences ?? []).filter(Boolean);
  if (preferences.length === 0) return true;

  // 2) Fetch candidate tracks. Consider pre-filtering via SQL with GIN index in production.
  const { data: tracks, error: tracksErr } = await supabase
    .from(TRACKS_TABLE)
    .select('id, tags');

  if (tracksErr) {
    console.error('[calculateCandidateTracksForJourney] Failed to fetch tracks', tracksErr);
    return false;
  }

  const prefSet: Set<string> = new Set<string>(preferences);

  const symmDiffSize = (a: Set<string>, b: Set<string>): number => {
    let inter = 0;
    for (const t of a) if (b.has(t)) inter++;
    return a.size + b.size - 2 * inter;
  };

  const intersectionSize = (a: Set<string>, b: Set<string>): number => {
    let inter = 0;
    for (const t of a) if (b.has(t)) inter++;
    return inter;
  };

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
    .filter((x: Scored) => x.diff <= MAX_SYMM_DIFF)
    .sort((a: Scored, b: Scored) =>
      (a.diff - b.diff)
      || (b.inter - a.inter)
      || (a.size - b.size)
      || a.trackId.localeCompare(b.trackId)
    )
    .slice(0, MAX_CANDIDATES);

  if (scored.length === 0) return true;

  const payload = scored.map((s: Scored, idx: number) => ({
    journey_id: journeyId,
    track_id: s.trackId,
    rank: idx + 1,
    score: (MAX_SYMM_DIFF - s.diff) * 100 + s.inter * 10 - s.size,
  }));

  const { error: upsertErr } = await supabase
    .from(JOURNEY_CANDIDATE_TRACKS_TABLE)
    .upsert(payload, { onConflict: 'journey_id,track_id' });

  if (upsertErr) {
    console.error('[calculateCandidateTracksForJourney] Failed to upsert candidates', upsertErr);
    return false;
  }

  return true;
}

/**
 * Creates a new journey and calculates its candidate tracks.
 */
export async function createJourney(preferences: string[]): Promise<boolean> {
  const { data: inserted, error } = await supabase
    .from(JOURNEYS_TABLE)
    .insert([{ preferences }])
    .select('id')
    .single<JourneyRow>();

  if (error || !inserted?.id) {
    console.error('[createJourney] Failed to create journey', error);
    return false;
  }

  const ok = await calculateCandidateTracksForJourney(inserted.id);
  return ok;
}
