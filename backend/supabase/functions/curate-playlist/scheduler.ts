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
    auth: {
      persistSession: false
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

  // Filter out candidates with missing artist location data
  const validCandidates = candidates.filter(
    (c: { tracks: { track_name: any; artists: { region_lat: null; region_lon: null; }; }; }) =>
      c.tracks &&
      typeof c.tracks.track_name === 'string' &&
      c.tracks.artists &&
      c.tracks.artists.region_lat !== null &&
      c.tracks.artists.region_lon !== null
  );

  if (validCandidates.length === 0) {
    console.error('No valid candidates with location data');
    return [];
  }

  // Normalize candidate objects to a consistent shape and include canonical fields
  const normalizedCandidates = validCandidates.map((c: { tracks: any; track_id: any; rank: any; score: any; }) => {
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
      artist_location: {
        x: artistObj.region_lat,
        y: artistObj.region_lon
      },
      tracks: track,
      artists: artistObj
    };
  });

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

    // Score candidates by distance and rank
    const scoredCandidates = availableCandidates.map((candidate) => {
      const artistLocation = candidate.artist_location;
      const distance = haversineDistance(currentPoint, artistLocation);
      const normalizedRank = candidate.rank / 100.00; // assuming rank 0-100
      const combinedScore = (distance * 0.5) + (normalizedRank * 0.5);
      return { candidate, combinedScore, distance, artistLocation };
    });

    scoredCandidates.sort((a, b) => a.combinedScore - b.combinedScore);

    // Find the first suitable track with strict duplicate-name lockout
    let selectedIndex = -1;
    for (let i = 0; i < scoredCandidates.length; i++) {
      const { candidate } = scoredCandidates[i];

      // Strict name lockout
      if (seenTrackNames.has(candidate.canonicalTrackName)) {
        continue;
      }

      // Dedupe by track ID as a secondary guard
      if (candidate.canonicalTrackId && seenTrackIds.has(candidate.canonicalTrackId)) {
        continue;
      }

      // Artist saturation check
      const artistCount = artistCounts.get(candidate.canonicalArtistId) || 0;
      if (artistCount >= ARTIST_SATURATION_LIMIT) {
        continue;
      }

      // Duration must fit remaining time budget
      if (candidate.duration_ms > timeBudget) {
        continue;
      }

      selectedIndex = i;
      break;
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

    // Advance to next point if the selected track duration covers the point duration
    const pointDurationMs = durations[currentPointIndex] * 1000;
    if (selected.candidate.duration_ms >= pointDurationMs) {
      currentPointIndex++;
    }
  }

  return playlist;
}