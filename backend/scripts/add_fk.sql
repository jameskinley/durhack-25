-- Add foreign key constraint from journey_candidate_tracks.track_id to tracks.track_id
ALTER TABLE public.journey_candidate_tracks
ADD CONSTRAINT journey_candidate_tracks_track_id_fkey 
FOREIGN KEY (track_id) 
REFERENCES public.tracks (track_id) 
ON DELETE CASCADE;

-- Create an index on track_id for better join performance (if not already exists)
CREATE INDEX IF NOT EXISTS journey_candidate_tracks_track_id_idx 
ON public.journey_candidate_tracks 
USING btree (track_id);