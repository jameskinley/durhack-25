import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.36.0';

// Keep local editors happy; Deno provides this at runtime on Supabase Edge
declare const Deno: { env: { get: (key: string) => string | undefined } };

function getClient(): SupabaseClient {
    const url = Deno.env.get('SUPABASE_URL');
    // Support either SUPABASE_SERVICE_ROLE (recommended) or SUPABASE_SERVICE_ROLE_KEY
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !serviceKey) {
        console.error('[create-journey/lib] Missing required env vars', {
            hasUrl: Boolean(url),
            hasServiceRole: Boolean(serviceKey)
        });
        throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE');
    }
  return createClient(url, serviceKey, {
    auth: { persistSession: false },
    global: {
      headers: { 'Cache-Control': 'no-store' },
      fetch: (input: RequestInfo | URL, init?: RequestInit) =>
        fetch(input, { ...(init ?? {}), cache: 'no-store' as RequestCache })
    }
  });
}

// Table names (adjust to your schema if different)
const JOURNEYS_TABLE = 'journeys';

type UUID = string;

type JourneyRow = {
    journey_id: UUID;
    preferences: string[];
};

/**
 * Calculates candidate tracks for a journey.
 */
async function calculateCandidateTracksForJourney(journeyId: string): Promise<boolean> {
  const supabase = getClient();
  if (!journeyId) {
    console.error('[calculateCandidateTracksForJourney] missing journeyId');
    return false;
  }

  const params = {
    p_journey_id: journeyId
  };

  const { data, error } = await supabase
    .rpc('calculate_candidate_tracks_v2', params);

  if (error) {
    console.error('[calculateCandidateTracksForJourney] RPC error:', error);
    return false;
  }

  // Normalize result shapes from Supabase
  let result: any = data;
  if (Array.isArray(result) && result.length) result = result[0];

  // Some Supabase versions wrap jsonb returns as { "<fn_name>": <json> }
  if (result && typeof result === 'object' && Object.keys(result).length === 1) {
    const onlyKey = Object.keys(result)[0];
    const candidate = (result as any)[onlyKey];
    if (candidate && typeof candidate === 'object') result = candidate;
  }

  // If it's a JSON string, try parse
  if (typeof result === 'string') {
    try { result = JSON.parse(result); } catch (e) { /* ignore */ }
  }

  console.debug('[calculateCandidateTracksForJourney] rpc result:', result);

  // Interpret success
  if (result === true || result === 't') return true;
  if (result && typeof result === 'object' && result.success === true) return true;

  console.error('[calculateCandidateTracksForJourney] RPC reported failure:', result);
  return false;
}


/**
 * Creates a new journey and calculates its candidate tracks.
 */
export async function createJourney(preferences: string[]): Promise<{ ok: boolean; id?: string }> {
    const supabase = getClient();
    const { data: inserted, error } = await supabase
        .from(JOURNEYS_TABLE)
        .insert([{ preferences }])
        .select('journey_id')
        .single<JourneyRow>();

    console.log("inserted:", inserted);

    if (error || !inserted?.journey_id) {
        console.error('[createJourney] Failed to create journey', error);
        return { ok: false };
    }

    const ok = await calculateCandidateTracksForJourney(inserted.journey_id);
    return { ok, id: inserted.journey_id };
}
