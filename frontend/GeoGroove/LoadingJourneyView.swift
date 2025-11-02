//
//  LoadingJourneyView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI
import CoreLocation
import MapKit
import Supabase

struct LoadingJourneyView: View {
    
    let startLocation: String
    let endLocation: String
    let startCoordinate: CLLocationCoordinate2D
    let endCoordinate: CLLocationCoordinate2D
    let transportType: RouteOptionsView.TransportType
    let genres: String
    let decades: String
    let route: MKRoute?
    
    @State private var isAnimating = false
    @State private var showSongs = false
    @State private var songs: [Song] = []
    @State private var journeyId: String?
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.purple.opacity(0.8),
                    Color.blue.opacity(0.8),
                    Color.cyan.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Animated musical notes
                ZStack {
                    ForEach(0..<3) { index in
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))
                            .offset(
                                x: isAnimating ? CGFloat.random(in: -50...50) : 0,
                                y: isAnimating ? CGFloat.random(in: -100...(-20)) : 0
                            )
                            .opacity(isAnimating ? 0 : 1)
                            .animation(
                                Animation.easeInOut(duration: 2)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.3),
                                value: isAnimating
                            )
                    }
                    
                    Image(systemName: "map.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                .frame(height: 150)
                
                // Loading text
                VStack(spacing: 16) {
                    Text("Preparing Your Musical Journey")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Curating the perfect soundtrack for your route...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Animated loading dots
                HStack(spacing: 12) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .scaleEffect(isAnimating ? 1.0 : 0.5)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: isAnimating
                            )
                    }
                }
                .padding(.top, 20)
                
                Spacer()
            }
        }
        .onAppear {
            print("🎵 LoadingJourneyView appeared")
            isAnimating = true
            fetchSongs()
        }
        .fullScreenCover(isPresented: $showSongs) {
            JourneyView(
                songs: songs,
                startLocation: startLocation,
                endLocation: endLocation,
                startCoordinate: startCoordinate,
                endCoordinate: endCoordinate
            )
        }
        .onChange(of: showSongs) { oldValue, newValue in
            print("🎵 showSongs changed from \(oldValue) to \(newValue)")
        }
    }
    
    private func fetchSongs() {
        print("🎵 Starting two-step journey creation flow...")
        
        // Step 1: Create a journey with preferences (genres + decades)
        // If the user selected "Any" for both genre and decade, send an empty list
        // to indicate no preference. Also ignore individual "Any" or empty values.
        let normalizedGenres = self.genres.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDecades = self.decades.trimmingCharacters(in: .whitespacesAndNewlines)

        var preferences: [String] = []
        if normalizedGenres.caseInsensitiveCompare("Any") == .orderedSame &&
            normalizedDecades.caseInsensitiveCompare("Any") == .orderedSame {
            // both explicitly "Any" -> send empty list
            preferences = []
        } else {
            if !normalizedGenres.isEmpty && normalizedGenres.caseInsensitiveCompare("Any") != .orderedSame {
                preferences.append(normalizedGenres)
            }
            if !normalizedDecades.isEmpty && normalizedDecades.caseInsensitiveCompare("Any") != .orderedSame {
                preferences.append(normalizedDecades)
            }
        }
        
        SupabaseService.shared.createJourney(preferences: preferences) { result in
            switch result {
            case .success(let journeyId):
                print("🎵 Journey created with ID: \(journeyId)")
                self.journeyId = journeyId
                
                // Step 2: Curate a playlist for this journey
                self.curatePlaylist(journeyId: journeyId)
                
            case .failure(let error):
                print("🎵 Failed to create journey: \(error.localizedDescription). Using mock data.")
                let mockTracks = self.generateDummyPlaylistTracks()
                DispatchQueue.main.async { self.enrichPlaylistTracks(mockTracks) }
            }
        }
    }
    
    private func curatePlaylist(journeyId: String) {
        print("🎵 Curating playlist for journey...")
        
        // Extract all points from the route polyline
        var points: [LocationPoint] = []
        if let route = route {
            // Get all coordinates from the polyline
            let polyline = route.polyline
            let pointCount = polyline.pointCount
            var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
            polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
            
            // Convert to LocationPoint array
            points = coordinates.map { LocationPoint(x: $0.latitude, y: $0.longitude) }
            print("🎵 Extracted \(points.count) points from route polyline")
        } else {
            // Fallback to just start and end
            points = [
                LocationPoint(x: startCoordinate.latitude, y: startCoordinate.longitude),
                LocationPoint(x: endCoordinate.latitude, y: endCoordinate.longitude)
            ]
            print("🎵 No route available; using start and end coordinates only")
        }
        
        // Use actual duration from route, or estimate based on transport type
        let duration: [Int]
        if let route = route {
            let durationInSeconds = Int(route.expectedTravelTime)
            duration = [durationInSeconds]
            print("🎵 Using route duration: \(durationInSeconds) seconds (\(durationInSeconds/60) minutes)")
        } else {
            // Fallback estimate based on transport type
            let estimatedDuration: Int
            switch transportType {
            case .driving:
                estimatedDuration = 1200 // 20 minutes
            case .transit:
                estimatedDuration = 1500 // 25 minutes
            }
            duration = [estimatedDuration]
            print("🎵 Using estimated duration: \(estimatedDuration) seconds")
        }
        
        SupabaseService.shared.curatePlaylist(journeyId: journeyId, points: points, duration: duration) { result in
            switch result {
            case .success(let playlistTracks):
                let validTracks = playlistTracks.filter { $0.type == "track" }
                print("🎵 Received \(playlistTracks.count) items, \(validTracks.count) are tracks")
                
                if validTracks.isEmpty {
                    print("🎵 No tracks returned; falling back to mock data")
                    let mockTracks = self.generateDummyPlaylistTracks()
                    DispatchQueue.main.async { self.enrichPlaylistTracks(mockTracks) }
                } else {
                    DispatchQueue.main.async { self.enrichPlaylistTracks(validTracks) }
                }
                
            case .failure(let error):
                print("🎵 Failed to curate playlist: \(error.localizedDescription). Using mock data.")
                let mockTracks = self.generateDummyPlaylistTracks()
                DispatchQueue.main.async { self.enrichPlaylistTracks(mockTracks) }
            }
        }
    }
    
    
    /// Enrich playlist tracks (from backend) by querying the Spotify Web API for each track to
    /// retrieve the Spotify track id and album artwork URL. Requires `SpotifyAuthManager.shared.accessToken`.
    private func enrichPlaylistTracks(_ tracks: [PlaylistTrack]) {
        var results: [Song?] = Array(repeating: nil, count: tracks.count)
        let group = DispatchGroup()
        
        let token = SpotifyAuthManager.shared.accessToken
        
        for (index, track) in tracks.enumerated() {
            group.enter()
            
            // Build Spotify search query: prefer exact match on track name + artist
            let query = "track:\(track.track) artist:\(track.artist)"
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                // Fall back to creating Song without Spotify metadata
                let fallbackSong = Song(
                    id: String(index),
                    name: track.track,
                    artist: track.artist,
                    location: "Lat: \(track.location.x), Lon: \(track.location.y)",
                    bio: track.comment ?? "",
                    latitude: track.location.x,
                    longitude: track.location.y,
                    artImageUrl: "",
                    songId: ""
                )
                DispatchQueue.main.async { results[index] = fallbackSong }
                group.leave()
                continue
            }
            
            let urlStr = "https://api.spotify.com/v1/search?q=\(encoded)&type=track&limit=1"
            guard let url = URL(string: urlStr) else {
                group.leave(); continue
            }
            
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
            
            URLSession.shared.dataTask(with: req) { data, resp, err in
                var artImageUrl = ""
                var spotifyId = ""
                var bioText = track.comment ?? ""
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tracksObj = json["tracks"] as? [String: Any],
                   let items = tracksObj["items"] as? [[String: Any]],
                   let first = items.first {
                    spotifyId = first["id"] as? String ?? ""
                    if let album = first["album"] as? [String: Any],
                       let images = album["images"] as? [[String: Any]],
                       let firstImage = images.first,
                       let imageUrl = firstImage["url"] as? String {
                        artImageUrl = imageUrl
                    }
                } else {
                    // If Spotify call fails (no token or network), we can fallback to empty image/id
                    if let http = resp as? HTTPURLResponse {
                        print("Spotify search HTTP \(http.statusCode) for \(track.track) by \(track.artist)")
                    } else if let err = err {
                        print("Spotify search error: \(err.localizedDescription)")
                    } else {
                        print("Spotify search: no data for \(track.track)")
                    }
                }
                
                /*
                 API CALL 3 (optional): fetch bio/comment from backend using either backend track id
                 or the spotifyId obtained above. Keep this template for when you hook up the bio API.
                 
                 if !spotifyId.isEmpty {
                 let bioURL = URL(string: "https://your-api.com/track/\(spotifyId)/bio")!
                 var bioRequest = URLRequest(url: bioURL)
                 bioRequest.httpMethod = "GET"
                 
                 URLSession.shared.dataTask(with: bioRequest) { bioData, bioResp, bioErr in
                 if let bioData = bioData {
                 let decoder = JSONDecoder()
                 if let bioResponse = try? decoder.decode(BioResponse.self, from: bioData) {
                 bioText = bioResponse.bio
                 }
                 }
                 // Continue building Song object below (you can move creation into this closure if you need the bio)
                 }.resume()
                 }
                 */
                
                let song = Song(
                    id: spotifyId.isEmpty ? String(index) : spotifyId,
                    name: track.track,
                    artist: track.artist,
                    location: "Lat: \(track.location.x), Lon: \(track.location.y)",
                    bio: bioText,
                    latitude: track.location.x,
                    longitude: track.location.y,
                    artImageUrl: artImageUrl,
                    songId: spotifyId
                )
                
                DispatchQueue.main.async {
                    results[index] = song
                }
                
                group.leave()
            }.resume()
        }
        
        group.notify(queue: .main) {
            // Preserve original ordering by mapping the results array
            let final = results.compactMap { $0 }
            print("🎵 Enriched \(final.count) tracks with Spotify metadata")
            self.songs = final
            self.showSongs = true
        }
    }
    
    private func generateDummyPlaylistTracks() -> [PlaylistTrack] {
        return [
            PlaylistTrack(track: "Bohemian Rhapsody", artist: "Queen", artist_tags: ["rock"], location: LocationPoint(x: 51.5237, y: -0.1585), comment: "An operatic masterpiece.", type: "track"),
            PlaylistTrack(track: "Waterloo Sunset", artist: "The Kinks", artist_tags: ["rock"], location: LocationPoint(x: 51.5081, y: -0.1169), comment: "A bittersweet London love song.", type: "track"),
            PlaylistTrack(track: "London Calling", artist: "The Clash", artist_tags: ["punk"], location: LocationPoint(x: 51.5007, y: -0.1246), comment: "A punk anthem.", type: "track"),
            PlaylistTrack(track: "A Day in the Life", artist: "The Beatles", artist_tags: ["rock"], location: LocationPoint(x: 51.5099, y: -0.1342), comment: "A psychedelic classic.", type: "track"),
            PlaylistTrack(track: "Parklife", artist: "Blur", artist_tags: ["britpop"], location: LocationPoint(x: 51.5074, y: -0.1657), comment: "90s Britpop energy.", type: "track"),
            PlaylistTrack(track: "Common People", artist: "Pulp", artist_tags: ["britpop"], location: LocationPoint(x: 51.5171, y: -0.2068), comment: "A social critique.", type: "track"),
            PlaylistTrack(track: "River Deep Mountain High", artist: "Ike & Tina Turner", artist_tags: ["soul"], location: LocationPoint(x: 51.5076, y: -0.0994), comment: "Phil Spector's wall of sound.", type: "track"),
            PlaylistTrack(track: "God Save the Queen", artist: "Sex Pistols", artist_tags: ["punk"], location: LocationPoint(x: 51.5390, y: -0.1426), comment: "Controversial punk single.", type: "track")
        ]
    }
    
    private func generateDummyTrackResponses() -> [TrackResponse] {
        return [
            TrackResponse(track: "Bohemian Rhapsody", artist: "Queen", tags: ["rock"], location: TrackResponse.LocationData(lat: 51.5237, lon: -0.1585), type: "track", comment: "An operatic masterpiece."),
            TrackResponse(track: "Waterloo Sunset", artist: "The Kinks", tags: ["rock"], location: TrackResponse.LocationData(lat: 51.5081, lon: -0.1169), type: "track", comment: "A bittersweet London love song."),
            TrackResponse(track: "London Calling", artist: "The Clash", tags: ["punk"], location: TrackResponse.LocationData(lat: 51.5007, lon: -0.1246), type: "track", comment: "A punk anthem."),
            TrackResponse(track: "A Day in the Life", artist: "The Beatles", tags: ["rock"], location: TrackResponse.LocationData(lat: 51.5099, lon: -0.1342), type: "track", comment: "A psychedelic classic."),
            TrackResponse(track: "Parklife", artist: "Blur", tags: ["britpop"], location: TrackResponse.LocationData(lat: 51.5074, lon: -0.1657), type: "track", comment: "90s Britpop energy."),
            TrackResponse(track: "Common People", artist: "Pulp", tags: ["britpop"], location: TrackResponse.LocationData(lat: 51.5171, lon: -0.2068), type: "track", comment: "A social critique."),
            TrackResponse(track: "River Deep Mountain High", artist: "Ike & Tina Turner", tags: ["soul"], location: TrackResponse.LocationData(lat: 51.5076, lon: -0.0994), type: "track", comment: "Phil Spector's wall of sound."),
            TrackResponse(track: "God Save the Queen", artist: "Sex Pistols", tags: ["punk"], location: TrackResponse.LocationData(lat: 51.5390, lon: -0.1426), type: "track", comment: "Controversial punk single.")
        ]
    }
    private func formatLocation(_ location: TrackResponse.LocationData) -> String {
        return "Lat: \(location.lat), Lon: \(location.lon)"
    }
    
    
    private func generateDummySongs() -> [Song] {
        return [
            Song(
                id: "queen_001",
                name: "Bohemian Rhapsody",
                artist: "Queen",
                location: "Baker Street, London, UK",
                bio: "\"This iconic six-minute opus was recorded at various studios across London in 1975. The operatic section features multi-tracked harmonies that took weeks to perfect. Freddie Mercury's vision for this genre-defying masterpiece changed rock music forever. Legend has it that the band recorded over 180 vocal overdubs, pushing the studio's 24-track tape machines to their absolute limits.\"",
                latitude: 51.5237,
                longitude: -0.1585,
                artImageUrl: "https://example.com/queen_bohemian.jpg",
                songId: "queen_001"
            ),
            Song(
                id: "kinks_001",
                name: "Waterloo Sunset",
                artist: "The Kinks",
                location: "Waterloo Bridge, London",
                bio: "\"Ray Davies penned this melancholic love letter to London while recovering from illness in 1966. The song captures the bittersweet beauty of watching lovers meet at Waterloo Station as the sun sets over the Thames. Davies has called it his favourite Kinks composition, describing it as 'the most beautiful song in the English language.'\"",
                latitude: 51.5081,
                longitude: -0.1169,
                artImageUrl: "https://example.com/kinks_waterloo.jpg",
                songId: "kinks_001"
            ),
            Song(
                id: "clash_001",
                name: "London Calling",
                artist: "The Clash",
                location: "Westminster, London",
                bio: "\"The title track from The Clash's groundbreaking 1979 double album addressed social upheaval, nuclear anxiety, and cultural decay. Joe Strummer's urgent vocals and Mick Jones's driving guitar created a punk anthem that transcended the genre. The song's apocalyptic imagery reflected the band's view of London in the late 1970s, yet remains timelessly relevant.\"",
                latitude: 51.5007,
                longitude: -0.1246,
                artImageUrl: "https://example.com/clash_london.jpg",
                songId: "clash_001"
            ),
            Song(
                id: "beatles_001",
                name: "A Day in the Life",
                artist: "The Beatles",
                location: "Piccadilly Circus, London",
                bio: "\"This psychedelic masterpiece closed Sgt. Pepper's Lonely Hearts Club Band with an orchestral crescendo that redefined pop music's possibilities. Lennon and McCartney's contrasting sections merged seamlessly, while the famous orchestral build-up required a 40-piece orchestra. Producer George Martin later called it 'the most ambitious and innovative recording The Beatles ever made.'\"",
                latitude: 51.5099,
                longitude: -0.1342,
                artImageUrl: "https://example.com/beatles_day.jpg",
                songId: "beatles_001"
            ),
            Song(
                id: "blur_001",
                name: "Parklife",
                artist: "Blur",
                location: "Hyde Park, London",
                bio: "\"Damon Albarn's witty observation of British leisure culture became the anthem of 1990s Britpop. Actor Phil Daniels's cockney narration added authentic London flavour to this celebration of everyday moments. The song perfectly captured the zeitgeist of mid-90s Britain, when the nation briefly fell in love with itself again through music, fashion, and cultural pride.\"",
                latitude: 51.5074,
                longitude: -0.1657,
                artImageUrl: "https://example.com/blur_parklife.jpg",
                songId: "blur_001"
            ),
            Song(
                id: "pulp_001",
                name: "Common People",
                artist: "Pulp",
                location: "Ladbroke Grove, London",
                bio: "\"Jarvis Cocker's scathing critique of class tourism in Britain struck a chord with millions in 1995. The song tells the true story of a Greek art student he met at Central Saint Martins who wanted to 'live like common people.' Its razor-sharp social commentary and anthemic chorus made it one of the defining songs of the Britpop era.\"",
                latitude: 51.5171,
                longitude: -0.2068,
                artImageUrl: "https://example.com/pulp_common.jpg",
                songId: "pulp_001"
            ),
            Song(
                id: "turner_001",
                name: "River Deep Mountain High",
                artist: "Ike & Tina Turner",
                location: "Southbank, London",
                bio: "\"Phil Spector's 'Wall of Sound' production reached its zenith with this 1966 recording, which he called his greatest achievement. Tina Turner's powerhouse vocals soared over layers of orchestration in what Spector considered his magnum opus. Though initially overlooked in America, British audiences embraced it, launching the Turners to international stardom from their London performances.\"",
                latitude: 51.5076,
                longitude: -0.0994,
                artImageUrl: "https://example.com/turner_river.jpg",
                songId: "turner_001"
            ),
            Song(
                id: "pistols_001",
                name: "God Save the Queen",
                artist: "Sex Pistols",
                location: "Camden Town, London",
                bio: "\"Released during the Queen's Silver Jubilee in 1977, this controversial punk anthem challenged British patriotism and monarchy. The BBC banned it, yet it still reached number one despite being censored from official charts. Johnny Rotten's sneering delivery and the song's raw energy embodied punk's rejection of establishment values, forever changing British music culture.\"",
                latitude: 51.5390,
                longitude: -0.1426,
                artImageUrl: "https://example.com/pistols_god.jpg",
                songId: "pistols_001"
            )
        ]
    }
}

// Temporary struct for API responses (not a Song yet)
struct TrackResponse: Codable {
    let track: String
    let artist: String
    let tags: [String]
    let location: LocationData
    let type: String
    let comment: String?
    
    struct LocationData: Codable {
        let lat: Double
        let lon: Double
    }
}

// Song data model - final version after all API calls
struct Song: Identifiable, Codable {
    let id: String
    let name: String
    let artist: String
    let location: String
    let bio: String
    let latitude: Double
    let longitude: Double
    let artImageUrl: String
    let songId: String
}

//#Preview {
//    NavigationStack {
//        LoadingJourneyView(
//            startLocation: "Baker Street",
//            endLocation: "Kings Cross",
//            startCoordinate: CLLocationCoordinate2D(latitude: 51.5237, longitude: -0.1585),
//            endCoordinate: CLLocationCoordinate2D(latitude: 51.5308, longitude: -0.1238),
//            transportType: RouteOptionsView.TransportType.driving,
//            genres: "Rock",
//            decades: "1980s",
//            route: nil as MKRoute?
//        )
//    }
//}
