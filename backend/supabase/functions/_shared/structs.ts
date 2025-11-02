export interface Point {
    x: number; //lat
    y: number; //lon
}

export interface CuratePlaylistRequest {
    journeyId: string;
    points: Point[]; //ordered xy track (longitude, latitude)
    duration: number; //seconds
}

export interface UserModel {
    id: string;
    name: string;
    preferences: string[];
    artistPool: Artist[];
    candidateTracks: Track[];
}

export interface Artist {
    id: string;
    name: string;
    location: Point; // use some API to get lat/lon from location name
    tags: string[];
    comment?: string;
}

export interface Track {
    id: string;
    artist: Artist;
    artistId: string;
    title: string;
    tags: string[];
    duration: number; // in seconds
}

export interface PlaylistTrack { 
    track: string;
    artist: string;
    artist_tags?: string[];
    location: Point;
    comment?: string;
    type: 'track'  | 'bio';
}