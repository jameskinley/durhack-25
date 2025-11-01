import { Point, Track, Artist, PlaylistTrack } from "../_shared/structs.ts";
import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.36.0';

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
    return createClient(url, serviceKey, { auth: { persistSession: false } });
}

const supabase = getClient();

function haversineDistance(pointA: Point, pointB: Point): number {
    const R = 6371; // Radius of the Earth in kilometers
    const toRad = (deg: number) => deg * Math.PI / 180.00;
    const dLat = toRad(pointB.x - pointA.x);
    const dLon = toRad(pointB.y - pointA.y);
    const a = Math.sin(dLat / 2.0) ** 2 + Math.cos(toRad(pointA.x)) * Math.cos(toRad(pointB.x)) * Math.sin(dLon / 2.0) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c; // Distance in kilometers
}

const scoreDistance = (x: number, maxRadiusKm: number = 50): number => 1 / (1 + Math.exp(x - ((maxRadiusKm / 200.0) * 5)));

function scoreRecording(
    track: Track,
    artist: Artist,
    preferences: string[],
    point: Point
): number {
    const dist = haversineDistance(point, artist.location);

    //normalise to a score 0-100 where 100 is best
    const distanceScore = scoreDistance(dist) * 100;
    // Prefer artists/tracks that match user preferences; count overlaps once each
    const artistTagMatches = artist.tags.filter(tag => preferences.includes(tag)).length;
    const trackTagMatches = track.tags.filter(tag => preferences.includes(tag)).length;
    const tagIntersection = artistTagMatches + trackTagMatches;

    return distanceScore + (tagIntersection * 10);
}

export function curatePlaylist(journeyId: string, points: Point[], duration: number): PlaylistTrack[] {

    const candidateTracks = supabase.from('journey_candidate_tracks')
        .select('track_id, title, duration, tags, artistId')
        .eq('journey_id', journeyId);

    const artistIndex = new Map<string, Artist>();
    artists.forEach(a => artistIndex.set(a.id, a));

    //convert points into route checkpoints (every N minutes)
    const segments = chunkPoints(points, duration);

    const playlist: PlaylistTrack[] = [];
    let total = 0;
    // Track which artists we've already added a bio for in this playlist
    const biosAdded = new Set<string>();

    for (const point of segments.points) {
        const scored = tracks.map(track => ({
            track,
            score: scoreRecording(track, artistIndex.get(track.artistId)!, preferences, point)
        }));

        scored.sort((a, b) => b.score - a.score);

        let segAccum = 0;
        let i = 0;

        while (segAccum < segments.duration && i < scored.length) {
            const track = scored[i++].track;
            const artist = artistIndex.get(track.artistId)!;

            // occasionally insert a 60s artist bio BEFORE the track
            const shouldAddBio = Math.random() < 0.25 && !biosAdded.has(artist.id);
            const bioDuration = 60; // seconds
            if (shouldAddBio) {
                // Ensure adding the bio won't exceed segment window or total duration
                if (segAccum + bioDuration <= segments.duration && total + bioDuration <= duration) {
                    playlist.push({
                        track: `${artist.name} bio`,
                        artist: artist.name,
                        artist_tags: artist.tags,
                        location: artist.location,
                        comment: artist.comment ?? '',
                        type: 'bio'
                    });
                    segAccum += bioDuration;
                    total += bioDuration;
                    biosAdded.add(artist.id);
                }
            }

            // If adding this track would exceed total duration, we're done
            if (total + track.duration > duration) {
                return playlist;
            }

            playlist.push({
                track: track.title,
                artist: artist.name,
                location: artist.location,
                type: 'track'
            });

            segAccum += track.duration;
            total += track.duration;

            if (total >= duration) return playlist;
        }

    }

    return playlist;
}

// Break the route's raw points into evenly spaced checkpoints and assign a uniform
// per-segment duration window. The last segment may be shorter overall, but the
// global "total" guard in curatePlaylist ensures we don't overrun playlist duration.
function chunkPoints(points: Point[], totalDurationSeconds: number, windowSeconds: number = 300): { points: Point[]; duration: number } {
    if (!points || points.length === 0 || totalDurationSeconds <= 0) {
        return { points: [], duration: 0 };
    }

    const perSegment = Math.min(windowSeconds, totalDurationSeconds);
    const segmentsCount = Math.max(1, Math.ceil(totalDurationSeconds / perSegment));

    // Sample checkpoints evenly across the provided route points
    const sampled: Point[] = [];
    for (let i = 0; i < segmentsCount; i++) {
        const t = segmentsCount === 1 ? 0 : i / (segmentsCount - 1);
        const idx = Math.floor(t * (points.length - 1));
        sampled.push(points[idx]);
    }

    return { points: sampled, duration: perSegment };
}