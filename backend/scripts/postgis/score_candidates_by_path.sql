-- Enable PostGIS once per database
create extension if not exists postgis;

-- Optional: functional GiST index for fast KNN on artist coordinates without altering schema.
-- NOTE: This project uses region_lat/region_lon columns for artist centroid coordinates.
create index if not exists artists_geog_expr_gist
on public.artists
using gist (
  (ST_SetSRID(
     ST_MakePoint(region_lon, region_lat),
     4326
   )::geography)
);

-- Score journey candidates by minimal distance (km) to a geographic path built from chunked points.
-- Rank is considered first (ASC = best). Distance is used as a tie-breaker.
-- Inputs:
--   p_journey_id: the journey identifier
--   p_lats, p_lons: arrays of equal length (>=2) of lat/lon for the chunked path (order matters)
--   p_limit: number of rows to return (default 200)
--   p_max_km: optional corridor width in kilometers for an early spatial filter (default 50km)
-- Output columns:
--   track_id, rank, distance_km
create or replace function public.score_candidates_by_path_geog(
  p_journey_id uuid,
  p_lats double precision[],
  p_lons double precision[],
  p_limit integer default 200,
  p_max_km double precision default 50.0
)
returns table (
  track_id uuid,
  rank integer,
  distance_km double precision,
  title text,
  duration integer,
  tags text[],
  artist_id uuid,
  artist_name text,
  artist_tags text[],
  artist_lat double precision,
  artist_lon double precision
)
language sql
stable
as $$
  with
  -- Build a LINESTRING geography from ordered lat/lon arrays
  path_geog as (
    select ST_MakeLine(
             array_agg(
               ST_SetSRID(ST_MakePoint(pt.lon, pt.lat), 4326)
               order by pt.ord
             )
           )::geography as geog
    from (
      select la.val as lat, lo.val as lon, la.ord as ord
      from unnest(p_lats) with ordinality as la(val, ord)
      join unnest(p_lons) with ordinality as lo(val, ord) using (ord)
    ) pt
  ),
  cand as (
    select jct.track_id, jct.rank, t.artist_id
    from public.journey_candidate_tracks jct
    join public.tracks t on t.track_id = jct.track_id
    where jct.journey_id = p_journey_id
  ),
  artist_points as (
    select
      a.artist_id,
      ST_SetSRID(
        ST_MakePoint(a.region_lon, a.region_lat),
        4326
      )::geography as geog
    from public.artists a
  )
  select
    c.track_id,
    c.rank,
    ST_Distance(ap.geog, (select geog from path_geog)) / 1000.0 as distance_km,
  t.track_name as title,
  CEIL(t.duration_ms / 1000.0)::int as duration,
  t.tags,
  a.artist_id,
  a.artist_name as artist_name,
  t.tags as artist_tags,
    a.region_lat as artist_lat,
    a.region_lon as artist_lon
  from cand c
  join public.tracks t on t.track_id = c.track_id
  join public.artists a on a.artist_id = c.artist_id
  join artist_points ap on ap.artist_id = c.artist_id
  where ST_DWithin(ap.geog, (select geog from path_geog), p_max_km * 1000.0)
  order by c.rank asc, distance_km asc
  limit p_limit
$$;
