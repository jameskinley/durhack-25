import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.36.0';
import { PlaylistTrack, Point } from '../_shared/structs.ts';

function getClient(): SupabaseClient {
    const url = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !serviceKey) {
        console.error('Missing required env vars', {
            hasUrl: Boolean(url),
            hasServiceKey: Boolean(serviceKey)
        });
        throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE');
    }
    return createClient(url, serviceKey, { auth: { persistSession: false } });
}

const supabase = getClient();

function haversineDistance(pointA: Point, pointB: Point): number {
    const R = 6371;
    const toRad = (deg: number) => deg * Math.PI / 180.00;
    const dLat = toRad(pointB.x - pointA.x);
    const dLon = toRad(pointB.y - pointA.y);
    const a = Math.sin(dLat / 2.0) ** 2 + Math.cos(toRad(pointA.x)) * Math.cos(toRad(pointB.x)) * Math.sin(dLon / 2.0) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

function getPointDurations(points: Point[], duration: number): { points: Point[], durations: number[] } {
    const chunkTime = duration / points.length;
    const durations = new Array(points.length).fill(chunkTime);
    return { points, durations };
}

interface Candidate {
    journey_id: string;
    track_id: string;
    rank: number;
    score: number;
    tracks: {
        track_id: string;
        track_name: string;
        artist_id: string;
        duration_ms: number;
        tags: string[];
        artists: {
            artist_id: string;
            artist_name: string;
            region_lat: number;
            region_lon: number;
        };
    };
}

export async function scheduleTracks(journey_id: string, points: Point[], duration: number): Promise<PlaylistTrack[]> {
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

    // Filter out candidates with missing data
    const validCandidates = candidates.filter((c: { tracks: { artists: { region_lat: null; region_lon: null; }; }; }) => 
        c.tracks && 
        c.tracks.artists && 
        c.tracks.artists.region_lat !== null && 
        c.tracks.artists.region_lon !== null
    ) as Candidate[];

    if (validCandidates.length === 0) {
        console.error('No valid candidates with location data');
        return [];
    }

    // Get point durations for the journey
    const { points: journeyPoints, durations } = getPointDurations(points, duration);

    const playlist: PlaylistTrack[] = [];
    const seenTrackIds = new Set<string>();
    const artistCounts = new Map<string, number>();
    const artistsWithBios = new Set<string>();
    const BIO_DURATION_MS = 30000; // 30 seconds for bio
    const ARTIST_SATURATION_LIMIT = 3; // Max tracks per artist
    const BIO_TRIGGER_PERCENTAGE = 0.2; // Add bio after 20% of tracks
    
    let currentPointIndex = 0;
    let timeBudget = duration * 1000; // Convert to milliseconds
    const availableCandidates = [...validCandidates];
    let tracksSinceLastBioCheck = 0;
    let lastAddedArtist: { id: string; name: string; location: Point; tags: string[] } | null = null;

    while (timeBudget > 0 && availableCandidates.length > 0 && currentPointIndex < journeyPoints.length) {
        const currentPoint = journeyPoints[currentPointIndex];
        
        // Score each candidate based on distance and rank
        const scoredCandidates = availableCandidates.map(candidate => {
            const artistLocation: Point = {
                x: candidate.tracks.artists.region_lat,
                y: candidate.tracks.artists.region_lon
            };
            const distance = haversineDistance(currentPoint, artistLocation);
            // Lower score is better (combining distance and rank)
            // Normalize rank (0-1) and distance, then weight them
            const normalizedRank = candidate.rank / 100; // Assuming rank is 0-100
            const combinedScore = distance * 0.7 + normalizedRank * 0.3;
            return { candidate, combinedScore, distance, artistLocation };
        });

        // Sort by score (best first)
        scoredCandidates.sort((a, b) => a.combinedScore - b.combinedScore);

        // Find the first suitable track
        let selectedIndex = -1;
        for (let i = 0; i < scoredCandidates.length; i++) {
            const { candidate } = scoredCandidates[i];
            
            // Check if track is already in playlist
            if (seenTrackIds.has(candidate.track_id)) {
                continue;
            }

            // Check artist saturation
            const artistCount = artistCounts.get(candidate.tracks.artist_id) || 0;
            if (artistCount >= ARTIST_SATURATION_LIMIT) {
                continue;
            }

            // Check if track fits in remaining time budget
            if (candidate.tracks.duration_ms > timeBudget) {
                continue;
            }

            selectedIndex = i;
            break;
        }

        // If no suitable track found, try next point or break
        if (selectedIndex === -1) {
            currentPointIndex++;
            continue;
        }

        const selected = scoredCandidates[selectedIndex];

        // Add track to playlist
        playlist.push({
            track: selected.candidate.tracks.track_name,
            artist: selected.candidate.tracks.artists.artist_name,
            artist_tags: selected.candidate.tracks.tags,
            location: selected.artistLocation,
            type: 'track'
        });

        // Update tracking variables
        seenTrackIds.add(selected.candidate.track_id);
        artistCounts.set(selected.candidate.tracks.artist_id, (artistCounts.get(selected.candidate.tracks.artist_id) || 0) + 1);
        timeBudget -= selected.candidate.tracks.duration_ms;
        tracksSinceLastBioCheck++;

        // Store info about the artist we just added
        lastAddedArtist = {
            id: selected.candidate.tracks.artist_id,
            name: selected.candidate.tracks.artists.artist_name,
            location: selected.artistLocation,
            tags: selected.candidate.tracks.tags
        };

        // Remove selected candidate from available pool
        const candidateIndex = availableCandidates.findIndex(c => c.track_id === selected.candidate.track_id);
        if (candidateIndex !== -1) {
            availableCandidates.splice(candidateIndex, 1);
        }

        // Check if we should insert a bio (after 20% of tracks have been added since last bio)
        const totalTracksInPlaylist = playlist.filter(p => p.type === 'track').length;
        const shouldInsertBio = tracksSinceLastBioCheck >= Math.max(1, Math.ceil(totalTracksInPlaylist * BIO_TRIGGER_PERCENTAGE));
        
        if (shouldInsertBio && timeBudget >= BIO_DURATION_MS && lastAddedArtist) {
            // Only add bio if we haven't already added one for this artist
            if (!artistsWithBios.has(lastAddedArtist.id)) {
                playlist.push({
                    track: '', // No track for bio
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

        // Move to next point if we've used up its duration
        const pointDuration = durations[currentPointIndex] * 1000; // Convert to ms
        if (selected.candidate.tracks.duration_ms >= pointDuration) {
            currentPointIndex++;
        }
    }

    return playlist;
}