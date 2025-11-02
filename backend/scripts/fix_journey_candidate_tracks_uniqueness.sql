-- One-off cleanup: remove duplicate rows per (journey_id, track_id), keeping the best-ranked entry
WITH ranked AS (
  SELECT ctid, journey_id, track_id, rank,
         ROW_NUMBER() OVER (PARTITION BY journey_id, track_id ORDER BY rank ASC, score DESC) AS rn
  FROM public.journey_candidate_tracks
),
removed AS (
  DELETE FROM public.journey_candidate_tracks t
  USING ranked r
  WHERE t.ctid = r.ctid AND r.rn > 1
  RETURNING 1
)
SELECT COUNT(*) AS removed_duplicates FROM removed;

-- Enforce uniqueness going forward; create a unique index if it doesn't already exist
CREATE UNIQUE INDEX IF NOT EXISTS ux_journey_candidate_tracks_journey_track
  ON public.journey_candidate_tracks (journey_id, track_id);
