CREATE OR REPLACE FUNCTION public.calculate_candidate_tracks_v2(
  p_journey_id uuid,
  p_max_symm_diff integer DEFAULT 4,
  p_max_candidates integer DEFAULT 300, -- good enough
  p_rating_weight numeric DEFAULT 2.0   -- relative influence of rating in score
) RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  prefs_json jsonb;
  prefs text[] := ARRAY[]::text[];
  pref_count int := 0;
  inserted_count int := 0;
BEGIN
  -- existence check
  IF NOT EXISTS (SELECT 1 FROM public.journeys WHERE journey_id = p_journey_id) THEN
    RETURN jsonb_build_object('success', true, 'message', 'journey not found - nothing to do', 'affected', 0);
  END IF;

  -- read preferences as jsonb so we can safely coerce scalar OR array
  SELECT to_jsonb(preferences) INTO prefs_json
  FROM public.journeys
  WHERE journey_id = p_journey_id;

  IF prefs_json IS NULL THEN
    prefs := ARRAY[]::text[];
  ELSE
    IF jsonb_typeof(prefs_json) = 'array' THEN
      -- convert json array to lower-cased text[]
      SELECT array_agg(lower(e)) INTO prefs
      FROM (
        SELECT jsonb_array_elements_text(prefs_json) AS e
      ) sub;
      IF prefs IS NULL THEN prefs := ARRAY[]::text[]; END IF;
    ELSE
  -- scalar -> single-element array, lower-cased
  prefs := ARRAY[ lower(prefs_json::text) ];
    END IF;
  END IF;

  pref_count := cardinality(prefs);

  IF pref_count = 0 THEN
    DELETE FROM public.journey_candidate_tracks WHERE journey_id = p_journey_id;
    RETURN jsonb_build_object('success', true, 'message', 'preferences empty - candidates cleared', 'affected', 0);
  END IF;

  WITH computed AS (
    SELECT
      t.track_id,
      COALESCE(cardinality(t.tags),0) AS size,
      (
        SELECT COUNT(DISTINCT ut.tag)::int
        FROM unnest(coalesce(t.tags, '{}')) AS ut(tag)
        WHERE lower(ut.tag) = ANY (prefs)
      ) AS inter,
      -- Normalize rating to 0..100 against the max rating observed (fallback to 1 to avoid div/0)
      (
        (COALESCE(t.track_rating, 0)::numeric
         / NULLIF((SELECT GREATEST(COALESCE(MAX(tt.track_rating),0),1) FROM public.tracks tt), 0)
        ) * 100
      )::int AS rating_norm
    FROM public.tracks t
  ),
  enriched AS (
    SELECT
      c.track_id,
      c.size,
      c.inter,
      c.rating_norm,
      ( COALESCE(c.size,0) + pref_count - 2 * COALESCE(c.inter,0) )::int AS diff
    FROM computed c
  ),
  -- Ensure only one row per track_id before ranking; pick the best (lowest diff, highest inter, smallest size)
  deduped AS (
    SELECT DISTINCT ON (e.track_id)
      e.track_id,
      e.size,
      e.inter,
      e.rating_norm,
      e.diff
    FROM enriched e
    ORDER BY e.track_id, e.diff ASC, e.inter DESC, e.rating_norm DESC, e.size ASC
  ),
  filtered AS (
    SELECT
      d.*,
      ROW_NUMBER() OVER (ORDER BY d.diff ASC, d.inter DESC, d.rating_norm DESC, d.size ASC, d.track_id) AS rn
    FROM deduped d
    WHERE d.diff <= p_max_symm_diff
  ),
  final AS (
    SELECT
      p_journey_id::uuid AS journey_id,
      f.track_id,
      f.rn AS rank,
      (
        (p_max_symm_diff - f.diff) * 100
        + f.inter * 10
        + (f.rating_norm * p_rating_weight)
        - f.size
      )::int AS score
    FROM filtered f
    ORDER BY f.rn
    LIMIT p_max_candidates
  ),
  -- Remove existing candidates for this journey to avoid any legacy duplicates
  _clear AS (
    DELETE FROM public.journey_candidate_tracks WHERE journey_id = p_journey_id RETURNING 1
  ),
  ins AS (
    INSERT INTO public.journey_candidate_tracks (journey_id, track_id, rank, score)
    SELECT journey_id, track_id, rank, score FROM final
    ON CONFLICT (journey_id, track_id)
    DO UPDATE SET rank = EXCLUDED.rank, score = EXCLUDED.score
    RETURNING 1
  )
  SELECT count(*) INTO inserted_count FROM ins;

  RETURN jsonb_build_object('success', true, 'message', 'ok', 'affected', inserted_count);

EXCEPTION
  WHEN others THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', SQLERRM,
      'sqlstate', SQLSTATE
    );
END;
$$;
