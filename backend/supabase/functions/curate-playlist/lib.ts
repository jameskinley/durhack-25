import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Point, Track, Artist, PlaylistTrack } from "../_shared/structs.ts";
import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.36.0';

// In Edge/Deno runtime Deno is available; declare to satisfy non-Deno typecheckers
// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const Deno: any;

const LOG_PREFIX = '[curate-playlist]';
// Bio configuration
const BIO_DURATION_SECONDS = 60;
const BIO_ODDS_AFTER_TRACK = 0.10;
const SEGMENT_OVERFLOW_TOLERANCE = 30; // seconds
const INITIAL_MAX_KM = 30.0;
const MAX_RADIUS_KM = 150.0; // Don't search beyond this
const RADIUS_INCREMENT_KM = 20.0; // How much to increase radius each attempt

function logInfo(message: string, extra?: unknown) {
    if (extra !== undefined) console.info(`${LOG_PREFIX} ${message}`, extra);
    else console.info(`${LOG_PREFIX} ${message}`);
}

function logWarn(message: string, extra?: unknown) {
    if (extra !== undefined) console.warn(`${LOG_PREFIX} ${message}`, extra);
    else console.warn(`${LOG_PREFIX} ${message}`);
}

function logError(message: string, extra?: unknown) {
    if (extra !== undefined) console.error(`${LOG_PREFIX} ${message}`, extra);
    else console.error(`${LOG_PREFIX} ${message}`);
}

function getClient(): SupabaseClient {
    const url = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!url || !serviceKey) {
        logError('Missing required env vars', {
            hasUrl: Boolean(url),
            hasServiceRole: Boolean(serviceKey)
        });
        throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE');
    }
    return createClient(url, serviceKey, { auth: { persistSession: false } });
}

function haversineDistance(pointA: Point, pointB: Point): number {
    const R = 6371;
    const toRad = (deg: number) => deg * Math.PI / 180.00;
    const dLat = toRad(pointB.x - pointA.x);
    const dLon = toRad(pointB.y - pointA.y);
    const a = Math.sin(dLat / 2.0) ** 2 + Math.cos(toRad(pointA.x)) * Math.cos(toRad(pointB.x)) * Math.sin(dLon / 2.0) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

const scoreDistance = (distanceKm: number, maxRadiusKm: number = 50): number => 
    1 / (1 + Math.exp(distanceKm - ((maxRadiusKm / 200.0) * 5)));

function scoreByDistance(artist: Artist, point: Point): number {
    const distKm = haversineDistance(point, artist.location);
    return scoreDistance(distKm) * 100;
}

type RpcCandidate = {
    track_id: string;
    rank: number;
    distance_km: number;
    title: string | null;
    duration: number | null;
    tags: string[] | null;
    artist_id: string;
    artist_name: string | null;
    artist_tags: string[] | null;
    artist_lat: number | null;
    artist_lon: number | null;
};

async function fetchCandidates(
    supabase: SupabaseClient,
    journeyId: string,
    latArr: number[],
    lonArr: number[],
    maxKm: number
): Promise<RpcCandidate[]> {
    const rpcArgs = {
        p_journey_id: journeyId,
        p_lats: latArr,
        p_lons: lonArr,
        p_limit: 1000,
        p_max_km: maxKm,
    } as const;
    
    const { data: candidates, error: cErr } = await supabase.rpc('score_candidates_by_path_geog', rpcArgs);
    if (cErr) {
        logError('failed to score candidates via RPC', { error: cErr, maxKm });
        return [];
    }
    
    return (candidates ?? []) as RpcCandidate[];
}

export async function curatePlaylist(journeyId: string, points: Point[], duration: number): Promise<PlaylistTrack[]> {
    const supabase = getClient();
    if (!journeyId) {
        logError('missing journeyId');
        return [];
    }
    if (!points || points.length < 2) {
        logError('insufficient points');
        return [];
    }
    
    const segments = chunkPoints(points, duration);
    const latArr = segments.points.map(p => p.x);
    const lonArr = segments.points.map(p => p.y);
    const makePoint = (lat?: number | null, lon?: number | null): Point => 
        ({ x: Number(lat ?? 0), y: Number(lon ?? 0) });

    let currentRadius = INITIAL_MAX_KM;
    let allCandidates: RpcCandidate[] = [];
    let playlist: PlaylistTrack[] = [];
    
    // Keep trying with larger radius until we get a satisfactory playlist
    while (currentRadius <= MAX_RADIUS_KM) {
        logInfo(`Fetching candidates with radius ${currentRadius}km`);
        
        const newCandidates = await fetchCandidates(supabase, journeyId, latArr, lonArr, currentRadius);
        
        // Merge new candidates with existing, avoiding duplicates
        const existingIds = new Set(allCandidates.map(c => c.track_id));
        const uniqueNew = newCandidates.filter(c => !existingIds.has(c.track_id));
        allCandidates = [...allCandidates, ...uniqueNew];
        
        logInfo(`Total candidates: ${allCandidates.length} (${uniqueNew.length} new)`, {
            segments: segments.points.length,
            segmentWindowSeconds: segments.duration,
            totalDurationSeconds: duration,
            radiusKm: currentRadius,
        });

        playlist = assemblePlaylist(
            allCandidates,
            segments.duration,
            segments.points.length,
            duration,
            makePoint,
        );
        
        // Check if playlist is satisfactory (at least 80% of requested duration filled)
        const playlistDuration = calculatePlaylistDuration(playlist);
        const fillPercentage = (playlistDuration / duration) * 100;
        
        logInfo(`Playlist fill: ${fillPercentage.toFixed(1)}% (${playlistDuration}s / ${duration}s)`);
        
        if (fillPercentage >= 80 || currentRadius >= MAX_RADIUS_KM) {
            break;
        }
        
        logWarn(`Insufficient tracks found, expanding search radius`);
        currentRadius += RADIUS_INCREMENT_KM;
    }

    return playlist;
}

function calculatePlaylistDuration(playlist: PlaylistTrack[]): number {
    // Simplified: assume each track is ~180s and bio is 60s
    return playlist.reduce((sum, item) => {
        return sum + (item.type === 'bio' ? BIO_DURATION_SECONDS : 180);
    }, 0);
}

function assemblePlaylist(
    candidates: RpcCandidate[],
    segmentWindowSeconds: number,
    segmentsCount: number,
    totalDurationSeconds: number,
    makePoint: (lat?: number | null, lon?: number | null) => Point,
): PlaylistTrack[] {
    if (!Array.isArray(candidates) || candidates.length === 0) return [];

    const { tracks, artistIndex } = normalizeCandidates(candidates, makePoint);
    logInfo('normalized candidates', { tracks: tracks.length, artists: artistIndex.size });

    const playlist = planPlaylist(tracks, segmentsCount, segmentWindowSeconds, totalDurationSeconds);
    logInfo('assembled playlist', { items: playlist.length });
    return playlist;
}

function normalizeCandidates(
    candidates: RpcCandidate[],
    makePoint: (lat?: number | null, lon?: number | null) => Point,
): { tracks: Track[]; artistIndex: Map<string, Artist> } {
    const artistIndex = new Map<string, Artist>();
    const tracks: Track[] = [];
    console.log("example candidate:", candidates[0]);
    let missingDuration = 0;
    let convertedFromMs = 0;
    
    for (const row of candidates) {
        const artistId = row.artist_id;
        const artistName = (row.artist_name ?? 'Unknown Artist').trim();
        
        const artist = artistIndex.get(artistId) ?? {
            id: artistId,
            name: artistName,
            tags: (row.artist_tags ?? []) as string[],
            location: makePoint(row.artist_lat, row.artist_lon),
        };
        artistIndex.set(artistId, artist);

        const raw = Number(row.duration ?? 0);
        let d = raw;
        if (!Number.isFinite(raw) || raw <= 0) {
            d = 180;
            missingDuration++;
        } else if (raw > 1000) {
            d = Math.ceil(raw / 1000);
            convertedFromMs++;
        } else {
            d = Math.round(raw);
        }
        
        tracks.push({
            id: row.track_id,
            artist,
            artistId,
            title: row.title ?? 'Unknown Title',
            tags: (row.tags ?? []) as string[],
            duration: d,
        });
    }
    
    if (missingDuration > 0) logWarn('filled missing/invalid durations with defaults', { count: missingDuration });
    if (convertedFromMs > 0) logInfo('converted durations from ms to seconds', { count: convertedFromMs });
    return { tracks, artistIndex };
}

// ============================================================================
// Track selection helpers
// ============================================================================

interface TrackSelectionContext {
    usedTrackIds: Set<string>;
    seenTitleByArtist: Set<string>;
    artistPlayCount: Map<string, number>; // Key is normalized artist name
    artistCap: number;
}

interface DurationConstraints {
    segmentRemaining: number;
    totalRemaining: number;
    allowOverflow?: number;
}

const normTitle = (t: string) => t.trim().toLowerCase();
const normArtistName = (name: string) => name.trim().toLowerCase();

const isMeaningfulTitle = (t: string) => {
    const n = normTitle(t);
    return n.length > 0 && n !== 'unknown title';
};

function isTrackUsed(track: Track, context: TrackSelectionContext): boolean {
    return context.usedTrackIds.has(track.id);
}

function isDuplicateTitleForArtist(track: Track, context: TrackSelectionContext): boolean {
    if (!isMeaningfulTitle(track.title)) return false;
    const key = `${normArtistName(track.artist.name)}|${normTitle(track.title)}`;
    return context.seenTitleByArtist.has(key);
}

function exceedsArtistCap(track: Track, context: TrackSelectionContext): boolean {
    const artistKey = normArtistName(track.artist.name);
    const count = context.artistPlayCount.get(artistKey) ?? 0;
    return count >= context.artistCap;
}

function exceedsDuration(track: Track, constraints: DurationConstraints): boolean {
    if (track.duration > constraints.totalRemaining) return true;
    const segLimit = constraints.segmentRemaining + (constraints.allowOverflow ?? 0);
    return track.duration > segLimit;
}

// Attempt 1: Strict - all constraints enforced
function selectTrackStrict(
    tracks: Track[],
    context: TrackSelectionContext,
    constraints: DurationConstraints
): Track | undefined {
    for (const t of tracks) {
        if (isTrackUsed(t, context)) continue;
        if (isDuplicateTitleForArtist(t, context)) continue;
        if (exceedsArtistCap(t, context)) continue;
        if (exceedsDuration(t, constraints)) continue;
        return t;
    }
    return undefined;
}

// Attempt 2: Relax title uniqueness but keep artist cap (STRICT)
function selectTrackRelaxedTitle(
    tracks: Track[],
    context: TrackSelectionContext,
    constraints: DurationConstraints
): Track | undefined {
    for (const t of tracks) {
        if (isTrackUsed(t, context)) continue;
        if (exceedsArtistCap(t, context)) continue; // Still strict on artist cap
        if (exceedsDuration(t, constraints)) continue;
        return t;
    }
    return undefined;
}

// Attempt 3: Allow segment overflow but keep artist cap (STRICT)
function selectTrackWithOverflow(
    tracks: Track[],
    context: TrackSelectionContext,
    constraints: DurationConstraints
): Track | undefined {
    const relaxedConstraints = {
        ...constraints,
        allowOverflow: SEGMENT_OVERFLOW_TOLERANCE
    };
    
    for (const t of tracks) {
        if (isTrackUsed(t, context)) continue;
        if (exceedsArtistCap(t, context)) continue; // Still strict on artist cap
        if (exceedsDuration(t, relaxedConstraints)) continue;
        return t;
    }
    return undefined;
}

// No "last resort" function that violates artist cap - we strictly enforce it

function selectNextTrack(
    tracks: Track[],
    context: TrackSelectionContext,
    constraints: DurationConstraints,
    segmentIndex: number
): Track | undefined {
    let chosen = selectTrackStrict(tracks, context, constraints);
    
    if (!chosen) {
        chosen = selectTrackRelaxedTitle(tracks, context, constraints);
    }
    
    if (!chosen) {
        chosen = selectTrackWithOverflow(tracks, context, constraints);
    }
    
    // If still no track found, we return undefined - caller will need more candidates
    if (!chosen) {
        logWarn(`Segment ${segmentIndex + 1}: no suitable tracks found (respecting artist cap)`);
    }
    
    return chosen;
}

// ============================================================================
// Bio insertion
// ============================================================================

interface BioContext {
    biosAdded: Set<string>;
    segmentRemaining: number;
    totalRemaining: number;
}

function shouldInsertBio(artist: Artist, context: BioContext): boolean {
    if (context.biosAdded.has(artist.id)) return false;
    if (Math.random() >= BIO_ODDS_AFTER_TRACK) return false;
    if (BIO_DURATION_SECONDS > context.segmentRemaining) return false;
    if (BIO_DURATION_SECONDS > context.totalRemaining) return false;
    return true;
}

function createBioItem(artist: Artist): PlaylistTrack {
    return {
        track: `${artist.name} bio`,
        artist: artist.name,
        artist_tags: artist.tags,
        location: artist.location,
        comment: (artist as any).comment ?? '',
        type: 'bio',
    } as any;
}

// ============================================================================
// Playlist planning
// ============================================================================

function calculateArtistCap(segmentsCount: number): number {
    return Math.max(1, Math.ceil(segmentsCount / 6));
}

function markTrackAsUsed(track: Track, context: TrackSelectionContext): void {
    context.usedTrackIds.add(track.id);
    
    if (isMeaningfulTitle(track.title)) {
        const key = `${normArtistName(track.artist.name)}|${normTitle(track.title)}`;
        context.seenTitleByArtist.add(key);
    }
    
    const artistKey = normArtistName(track.artist.name);
    const currentCount = context.artistPlayCount.get(artistKey) ?? 0;
    context.artistPlayCount.set(artistKey, currentCount + 1);
}

function planPlaylist(
    tracks: Track[],
    segmentsCount: number,
    segmentWindowSeconds: number,
    totalDurationSeconds: number,
): PlaylistTrack[] {
    if (!tracks.length || totalDurationSeconds <= 0) return [];

    const context: TrackSelectionContext = {
        usedTrackIds: new Set<string>(),
        seenTitleByArtist: new Set<string>(),
        artistPlayCount: new Map<string, number>(),
        artistCap: calculateArtistCap(segmentsCount),
    };
    
    const biosAdded = new Set<string>();
    const playlist: PlaylistTrack[] = [];
    let totalAccumulated = 0;

    logInfo(`Planning playlist with artist cap: ${context.artistCap} tracks per artist`);

    for (let s = 0; s < segmentsCount; s++) {
        const totalRemaining = Math.max(0, totalDurationSeconds - totalAccumulated);
        if (totalRemaining <= 0) break;
        
        const segLimit = Math.min(segmentWindowSeconds, totalRemaining);
        logInfo(`segment ${s + 1}/${segmentsCount}`, { segLimit, remaining: totalRemaining });

        let segAccum = 0;
        
        while (segAccum < segLimit) {
            const constraints: DurationConstraints = {
                segmentRemaining: segLimit - segAccum,
                totalRemaining: totalDurationSeconds - totalAccumulated,
            };
            
            const chosen = selectNextTrack(tracks, context, constraints, s);
            if (!chosen) break; // No suitable track found - need more candidates

            const artist = chosen.artist;
            const artistKey = normArtistName(artist.name);
            const currentCount = context.artistPlayCount.get(artistKey) ?? 0;
            
            playlist.push({
                track: chosen.title,
                artist: artist.name,
                location: artist.location,
                type: 'track',
            });
            
            segAccum += chosen.duration;
            totalAccumulated += chosen.duration;
            markTrackAsUsed(chosen, context);
            
            logInfo('added track', { 
                trackId: chosen.id, 
                title: chosen.title, 
                artist: artist.name,
                duration: chosen.duration,
                artistCount: currentCount + 1,
                artistCap: context.artistCap
            });

            // Try to insert bio
            const bioContext: BioContext = {
                biosAdded,
                segmentRemaining: segLimit - segAccum,
                totalRemaining: totalDurationSeconds - totalAccumulated,
            };
            
            if (shouldInsertBio(artist, bioContext)) {
                playlist.push(createBioItem(artist));
                segAccum += BIO_DURATION_SECONDS;
                totalAccumulated += BIO_DURATION_SECONDS;
                biosAdded.add(artist.id);
                logInfo('added bio after track', { artistId: artist.id, name: artist.name });
            }

            if (totalAccumulated >= totalDurationSeconds) break;
        }

        if (totalAccumulated >= totalDurationSeconds) break;
    }

    return playlist;
}

function chunkPoints(points: Point[], totalDurationSeconds: number, windowSeconds: number = 300): { points: Point[]; duration: number } {
    if (!points || points.length === 0 || totalDurationSeconds <= 0) {
        return { points: [], duration: 0 };
    }

    const perSegment = Math.min(windowSeconds, totalDurationSeconds);
    const segmentsCount = Math.max(1, Math.ceil(totalDurationSeconds / perSegment));

    const sampled: Point[] = [];
    for (let i = 0; i < segmentsCount; i++) {
        const t = segmentsCount === 1 ? 0 : i / (segmentsCount - 1);
        const idx = Math.floor(t * (points.length - 1));
        sampled.push(points[idx]);
    }

    return { points: sampled, duration: perSegment };
}