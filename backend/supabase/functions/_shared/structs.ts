export interface Point {
    x: number;
    y: number;
}

export interface CuratePlaylistRequest {
    userId: string;
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
    type: 'track'  | 'bio';
}