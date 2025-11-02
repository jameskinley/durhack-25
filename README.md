# GeoGroove

Turn your journey into a mixtape. GeoGroove curates a route‑aware playlist that evolves as you travel — blending where you are, where you’re going, and what you love to listen to.

## Why GeoGroove?

We’ve all played “human DJ” on road trips — picking tracks that fit the landscape, the mood, and the moment. GeoGroove makes that effortless. It builds a soundtrack that follows your route and feels connected to the places you pass.

## What it does

- Lets you pick a route and select a handful of tags/genres you’re into.
- Curates a playlist that balances three things:
  - Geography: artists near your route for a sense of place.
  - Taste: your chosen tags and similar tracks.
  - Quality: track ratings to keep the vibe strong.
- Ensures variety: prevents duplicate tracks, limits repeat artists, and adds just enough randomness so every run is fresh.
- Sprinkles in short artist “bios” for context as you move, making the experience more than just music.

## How it works (high level)

1. You set your route and preferences.
2. GeoGroove pulls a pool of candidate tracks from a refined dataset and geolocates artists by region.
3. A scheduler assembles the playlist by combining proximity, preference match, and rating into a lightweight score.
4. As your route progresses, the “current point” shifts and the mix adapts alongside it.

## What makes it different

- Route‑aware: your playlist follows your journey, not just your history.
- Place‑connected: discover artists tied to regions you pass.
- Balanced: geography leads, taste guides, quality refines.
- Varied: intentional controls on duplicates and artist repetition, plus smart randomness.

## A peek under the hood (no setup required)

- Data sources: a refined, tag‑rich music dataset (MusicBrainz‑derived) with geocoded artist regions.
- Smart curation: cost‑based scoring blends distance, rank (preference match), and rating; ties break with a top‑K random pick for variety.
- Clean results: case‑insensitive tag matching and strict de‑duping ensure each playlist is truly distinct.

## Privacy & respect for artists

- GeoGroove uses aggregated, publicly available metadata and does not store personal listening history.
- We highlight artists’ bios contextually to help you discover music connected to place.

## Roadmap

- AI‑generated bios and local stories for richer context.
- Deeper personalization that learns from each journey.
- Streaming integrations to push playlists to your player in real time.
- Broader geocoding coverage and refined diversity controls.

## Credits

Built by James (backend) and Alex (frontend) at DurHack.


