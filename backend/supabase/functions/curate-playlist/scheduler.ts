import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.36.0';
import { Point } from '../_shared/structs.ts';

function getClient() {
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) {
    console.error('Missing required env vars', {
      hasUrl: Boolean(url),
      hasServiceKey: Boolean(serviceKey)
    });
    throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE');
  }
  return createClient(url, serviceKey, {
    auth: { persistSession: false },
    // Prevent caching at the request layer for all PostgREST/RPC calls
    global: {
      headers: { 'Cache-Control': 'no-store' },
      fetch: (input: RequestInfo | URL, init?: RequestInit) => {
        return fetch(input, { ...(init ?? {}), cache: 'no-store' as RequestCache });
      }
    }
  });
}

const supabase = getClient();

function haversineDistance(pointA : Point, pointB : Point) {
  const R = 6371;
  const toRad = (deg : number) => deg * Math.PI / 180.0;
  const dLat = toRad(pointB.x - pointA.x);
  const dLon = toRad(pointB.y - pointA.y);
  const a =
    Math.sin(dLat / 2.0) ** 2 +
    Math.cos(toRad(pointA.x)) * Math.cos(toRad(pointB.x)) * Math.sin(dLon / 2.0) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function getPointDurations(points : Point[], duration: number) {
  const chunkTime = duration / points.length;
  const durations = new Array(points.length).fill(chunkTime);
  return {
    points,
    durations
  };
}

// Robust canonical name normalization: Unicode NFC, trim, collapse whitespace, lower-case
function normalizeName(name: string) {
  if (typeof name !== 'string') return '';
  return name
    .normalize('NFC')
    .trim()
    .replace(/\s+/g, ' ')
    .toLowerCase();
}

export async function scheduleTracks(journey_id : string, points : Point[], duration : number) {
  // Fetch candidate tracks with joined tracks and artists data
  const { data: candidates, error } = await supabase
    .from('journey_candidate_tracks')
    .select(`
      journey_id,
      track_id,
      rank,
      score,
      tracks!inner (
        track_id,
        track_name,
        artist_id,
        duration_ms,
        tags,
        artists!inner (
          artist_id,
          artist_name,
          region_lat,
          region_lon
        )
      )
    `)
    .eq('journey_id', journey_id)
    .order('rank', { ascending: true });

  if (error) {
    console.error('Failed to fetch candidates:', error);
    return [];
  }

  if (!candidates || candidates.length === 0) {
    console.log('No candidates found for journey:', journey_id);
    return [];
  }

  // Normalize all candidate objects to a consistent shape and include canonical fields
  const normalizedCandidates = (candidates || []).map((c: { tracks: any; track_id: any; rank: any; score: any; }) => {
    const track = c.tracks;
    const artistObj = track.artists || {};
    const canonicalName = normalizeName(track.track_name);
    return {
      raw: c,
      canonicalTrackId: track.track_id ?? c.track_id,
      canonicalTrackName: canonicalName,
      displayTrackName: track.track_name, // keep original for display
      canonicalArtistId: track.artist_id ?? artistObj.artist_id,
      canonicalArtistName: artistObj.artist_name ?? '',
      rank: c.rank ?? 0,
      score: c.score ?? 0,
      duration_ms: track.duration_ms ?? 0,
      tags: track.tags ?? null,
      artist_location: (artistObj.region_lat != null && artistObj.region_lon != null)
        ? { x: artistObj.region_lat, y: artistObj.region_lon }
        : null,
      tracks: track,
      artists: artistObj
    };
  });

  console.log('[scheduleTracks] candidates:', {
    total: normalizedCandidates.length,
    withLocation: normalizedCandidates.filter((c: any) => !!c.artist_location).length,
  });

  // Determine dynamic max rank to avoid saturating normalization when rank > 100
  const maxRank = normalizedCandidates.reduce((m: number, c: any) => Math.max(m, Number(c.rank ?? 0)), 1);
  // Determine min/max score for normalization (higher SQL score is better)
  const minScore = normalizedCandidates.reduce((m: number, c: any) => Math.min(m, Number(c.score ?? 0)), Number.POSITIVE_INFINITY);
  const maxScore = normalizedCandidates.reduce((m: number, c: any) => Math.max(m, Number(c.score ?? 0)), Number.NEGATIVE_INFINITY);

  // Prepare journey point durations and bookkeeping
  const { points: journeyPoints, durations } = getPointDurations(points, duration);
  const playlist = [];
  const seenTrackIds = new Set();
  const seenTrackNames = new Set(); // strict global lockout by normalized name
  const artistCounts = new Map();
  const artistsWithBios = new Set();

  const BIO_DURATION_MS = 30000; // 30 seconds for bio
  const ARTIST_SATURATION_LIMIT = 3; // Max tracks per artist
  const BIO_TRIGGER_PERCENTAGE = 0.2; // Add bio after 20% of tracks

  let currentPointIndex = 0;
  let timeBudget = duration * 1000; // convert seconds to milliseconds
  let remainingChunkMs = (durations[currentPointIndex] ?? 0) * 1000;

  // Pre-eliminate any duplicates by name from the candidate pool (keep highest-ranked instance)
  const bestByName = new Map();
  for (const c of normalizedCandidates) {
    const existing = bestByName.get(c.canonicalTrackName);
    if (!existing || c.rank < existing.rank) {
      bestByName.set(c.canonicalTrackName, c);
    }
  }
  let availableCandidates = Array.from(bestByName.values());

  let tracksSinceLastBioCheck = 0;
  let lastAddedArtist = null;

  while (timeBudget > 0 && availableCandidates.length > 0 && currentPointIndex < journeyPoints.length) {
    const currentPoint = journeyPoints[currentPointIndex];

    // Score candidates by distance and rank. Normalize distance to [0,1] to avoid dominating rank.
    // If location is missing, use rank-only scoring.
  const rawDistances: number[] = [];
    for (const c of availableCandidates) {
      if (c.artist_location) {
        rawDistances.push(haversineDistance(currentPoint, c.artist_location));
      }
    }
    const maxDistance = rawDistances.length ? Math.max(...rawDistances) : 0;

    const scoredCandidates = availableCandidates.map((candidate) => {
      const artistLocation = candidate.artist_location;
      const hasLoc = Boolean(artistLocation);
      const distanceKm = hasLoc ? haversineDistance(currentPoint, artistLocation as Point) : 0;
      console.log("distancekm", distanceKm);
      // Normalize distance: if we have a maxDistance, scale; else treat as 1 (neutral)
      const distanceNorm = hasLoc && maxDistance > 0 ? Math.min(distanceKm / maxDistance, 1) : 1;

      console.log("norm. distL", distanceNorm);
      // Normalize rank within [0,1] based on max observed rank; lower is better
      const denom = Math.max(1, (maxRank - 1));
      const normalizedRank = Math.min(Math.max(((Number(candidate.rank ?? 0) - 1) / denom), 0), 1);
      // Normalize score so that lower is worse, higher is better -> convert to cost
      let scoreCost = 0.5; // neutral
      if (Number.isFinite(minScore) && Number.isFinite(maxScore) && maxScore > minScore) {
        const scoreNorm = (Number(candidate.score ?? 0) - minScore) / (maxScore - minScore); // 0..1 (higher better)
        scoreCost = 1 - scoreNorm; // cost (lower better)
      }
      // Soft artist recency penalty to encourage variety
      const priorCount = (artistCounts.get(candidate.canonicalArtistId) || 0) as number;
      const artistPenalty = Math.min(priorCount * 0.15, 0.6);

  // Emphasize geography over all other factors when location exists
  const weightDistance = hasLoc ? 0.7 : 0.0; // location dominates when available
  const remainingWeight = 1 - weightDistance;
  // Split the remainder with a smaller share to rank and score
  const weightRank = remainingWeight * 0.66; // rank stronger than score within the remainder
  const weightScore = remainingWeight * 0.34;
  // Note: we treat this as a COST function (lower is better).
  // - distanceNorm is 0 for closest, 1 for farthest
  // - normalizedRank is 0 for best rank, 1 for worst
  // - scoreCost inverts the SQL score (higher score -> lower cost)
  // We then sort ASC to pick the minimum-cost candidate.
  const combinedScore = (weightDistance * distanceNorm) + (weightRank * normalizedRank) + (weightScore * scoreCost) + artistPenalty;
      return { candidate, combinedScore, distance: distanceKm, artistLocation };
    });

    scoredCandidates.sort((a, b) => a.combinedScore - b.combinedScore);

    // Build shortlist of suitable candidates (respecting dedupe/caps/budget)
    const shortlist: number[] = [];
    for (let i = 0; i < scoredCandidates.length && shortlist.length < 12; i++) {
      const { candidate } = scoredCandidates[i];
      if (seenTrackNames.has(candidate.canonicalTrackName)) continue;
      if (candidate.canonicalTrackId && seenTrackIds.has(candidate.canonicalTrackId)) continue;
      const artistCount = artistCounts.get(candidate.canonicalArtistId) || 0;
      if (artistCount >= ARTIST_SATURATION_LIMIT) continue;
      if (candidate.duration_ms > timeBudget) continue;
      shortlist.push(i);
    }

    // Randomize among top-K in shortlist to introduce variety
    let selectedIndex = -1;
    if (shortlist.length > 0) {
      const K = Math.min(5, shortlist.length);
      const pick = Math.floor(Math.random() * K);
      selectedIndex = shortlist[pick];
    }

    // No suitable candidate at this point, advance to next point
    if (selectedIndex === -1) {
      currentPointIndex++;
      continue;
    }

    const selected = scoredCandidates[selectedIndex];

    // Final guard: do not add if the normalized name exists (defensive)
    if (seenTrackNames.has(selected.candidate.canonicalTrackName)) {
      // Remove it from the pool and continue loop safely
      availableCandidates = availableCandidates.filter(
        (c) => c.canonicalTrackName !== selected.candidate.canonicalTrackName
      );
      continue;
    }

    // Add track to playlist
    playlist.push({
      track: selected.candidate.displayTrackName,
      artist: selected.candidate.canonicalArtistName || selected.candidate.tracks.artists.artist_name,
      artist_tags: selected.candidate.tags,
      location: selected.artistLocation,
      type: 'track'
    });

    // Mark seen by name (primary) and by ID (secondary)
    seenTrackNames.add(selected.candidate.canonicalTrackName);
    if (selected.candidate.canonicalTrackId) {
      seenTrackIds.add(selected.candidate.canonicalTrackId);
    }

    // Update artist count using canonicalArtistId
    const artistId = selected.candidate.canonicalArtistId;
    artistCounts.set(artistId, (artistCounts.get(artistId) || 0) + 1);

    timeBudget -= selected.candidate.duration_ms;
    tracksSinceLastBioCheck++;

    // Store last added artist info for potential bio insertion
    lastAddedArtist = {
      id: artistId,
      name: selected.candidate.canonicalArtistName,
      location: selected.artistLocation,
      tags: selected.candidate.tags
    };

    // Remove all candidates with the same normalized name (strict)
    availableCandidates = availableCandidates.filter(
      (c) => c.canonicalTrackName !== selected.candidate.canonicalTrackName
    );

    // Check for bio insertion
    const totalTracksInPlaylist = playlist.filter((p) => p.type === 'track').length;
    const shouldInsertBio =
      tracksSinceLastBioCheck >= Math.max(1, Math.ceil(totalTracksInPlaylist * BIO_TRIGGER_PERCENTAGE));

    if (shouldInsertBio && timeBudget >= BIO_DURATION_MS && lastAddedArtist) {
      if (!artistsWithBios.has(lastAddedArtist.id)) {
        playlist.push({
          track: '',
          artist: lastAddedArtist.name,
          artist_tags: lastAddedArtist.tags,
          location: lastAddedArtist.location,
          comment: `Biography of ${lastAddedArtist.name}`,
          type: 'bio'
        });
        artistsWithBios.add(lastAddedArtist.id);
        timeBudget -= BIO_DURATION_MS;
        tracksSinceLastBioCheck = 0;
      }
    }

    // Advance along route by consuming current chunk duration with each added track
    remainingChunkMs -= selected.candidate.duration_ms;
    while (remainingChunkMs <= 0 && currentPointIndex < journeyPoints.length - 1) {
      currentPointIndex++;
      remainingChunkMs += (durations[currentPointIndex] ?? 0) * 1000;
    }
  }

  return playlist;
}