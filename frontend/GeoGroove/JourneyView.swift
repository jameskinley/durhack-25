//
//  JourneyView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI
import MapKit

struct JourneyView: View {
    
    let songs: [Song]
    let startLocation: String
    let endLocation: String
    let startCoordinate: CLLocationCoordinate2D
    let endCoordinate: CLLocationCoordinate2D
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentlyPlaying: String?
    @State private var currentIndex: Int = 0
    @State private var isPlaying: Bool = false
    @State private var showMapModal = false
    @State private var journeyStartTime = Date()
    @State private var estimatedDuration: TimeInterval = 3600 // 1 hour default
    
    var progressPercentage: Double {
        guard songs.count > 0 else { return 0 }
        // Use (songs.count - 1) as denominator so the bar reaches 100% at the last song
        return Double(currentIndex) / Double(max(1, songs.count - 1))
    }
    
    var timeRemaining: String {
        let elapsed = Date().timeIntervalSince(journeyStartTime)
        let remaining = max(0, estimatedDuration - elapsed)
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.1),
                        Color.blue.opacity(0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                HStack(spacing: 0) {
                    // Progress Sidebar
                    VStack(spacing: 0) {
                        // Time remaining at top
                        VStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(timeRemaining)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 60)
                        .padding(.vertical, 12)
                        // Make this background match the progress bar track
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .top) {
                                // Background track
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 4)
                                    .frame(maxWidth: .infinity)
                                
                                // Progress fill
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .purple]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 4, height: geometry.size.height * progressPercentage)
                                    .frame(maxWidth: .infinity)
                                
                                // Song position indicators
                                ForEach(Array(songs.enumerated()), id: \.element.id) { index, _ in
                                    let position = CGFloat(index) / CGFloat(max(1, songs.count - 1))
                                    Circle()
                                        .fill(index <= currentIndex ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                        .offset(y: geometry.size.height * position - 4)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 8)
                        
                        // Destination indicator at bottom
                        VStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            Text("End")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .frame(width: 60)
                        .padding(.vertical, 12)
                        // Make this background match the progress bar track
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                    }
                    .frame(width: 60)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    
                    // Main Content
                    VStack(spacing: 0) {
                        // Header Card
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "music.note.list")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your Musical Journey")
                                        .font(.headline)
                                    Text("\(startLocation) → \(endLocation)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("\(songs.count) songs")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(12)
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                        
                        // Songs and Bios List
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                                        // Bio Card (appears before each song)
                                        BioCard(bio: song.bio)

                                        // Song Card
                                        SongCard(
                                            song: song,
                                            index: index + 1,
                                            isPlaying: currentlyPlaying == song.id && isPlaying,
                                            isCurrent: index == currentIndex,
                                            onTap: {
                                                // Build ordered URIs for the full playlist
                                                let uris = songs.compactMap { s -> String? in
                                                    guard !s.songId.isEmpty else { return nil }
                                                    if s.songId.starts(with: "spotify:") { return s.songId }
                                                    return "spotify:track:\(s.songId)"
                                                }

                                                // If tapped a different track, skip to that index in the queue
                                                if song.id != currentlyPlaying {
                                                    SpotifyAuthManager.shared.play(uris: uris, startIndex: index) { success, message in
                                                        DispatchQueue.main.async {
                                                            if success {
                                                                currentlyPlaying = song.id
                                                                currentIndex = index
                                                                isPlaying = true
                                                                journeyStartTime = Date()
                                                            } else {
                                                                print("Playback error: \(message ?? "unknown")")
                                                            }
                                                        }
                                                    }
                                                } else {
                                                    // Tapped the currently playing track -> toggle pause/resume
                                                    if isPlaying {
                                                        SpotifyAuthManager.shared.pause { success, message in
                                                            DispatchQueue.main.async {
                                                                if success {
                                                                    isPlaying = false
                                                                } else {
                                                                    print("Pause error: \(message ?? "unknown")")
                                                                }
                                                            }
                                                        }
                                                    } else {
                                                        SpotifyAuthManager.shared.play(uris: uris, startIndex: index) { success, message in
                                                            DispatchQueue.main.async {
                                                                if success {
                                                                    isPlaying = true
                                                                } else {
                                                                    print("Playback error: \(message ?? "unknown")")
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                    }
                }
                
                // Play All Button
                VStack {
                    Spacer()
                    
                    Button(action: {
                        // Start playback of all songs in order using Spotify API
                        let uris = songs.compactMap { song -> String? in
                            guard !song.songId.isEmpty else { return nil }
                            // Ensure spotify:track: prefix
                            if song.songId.starts(with: "spotify:") {
                                return song.songId
                            } else {
                                return "spotify:track:\(song.songId)"
                            }
                        }

                        guard !uris.isEmpty else {
                            print("No playable Spotify URIs available")
                            return
                        }

                        

                        if !isPlaying {
                            // Start playback from the beginning
                            SpotifyAuthManager.shared.play(uris: uris, startIndex: 0) { success, message in
                                DispatchQueue.main.async {
                                    if success {
                                        print("Playback started with \(uris.count) tracks")
                                        isPlaying = true
                                    } else {
                                        print("Playback error: \(message ?? "unknown")")
                                    }
                                }
                            }
                        } else {
                            // Pause playback
                            SpotifyAuthManager.shared.pause { success, message in
                                DispatchQueue.main.async {
                                    if success {
                                        print("Playback paused")
                                        isPlaying = false
                                    } else {
                                        print("Pause error: \(message ?? "unknown")")
                                    }
                                }
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            Text(isPlaying ? "Pause Journey" : "Play Journey")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.horizontal, 80) // Account for sidebar
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showMapModal = true }) {
                        Image(systemName: "map.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showMapModal) {
                MapModalView(
                    songs: songs,
                    startCoordinate: startCoordinate,
                    endCoordinate: endCoordinate,
                    startLocation: startLocation,
                    endLocation: endLocation
                )
            }
        }
    }
}

// Bio Card Component
struct BioCard: View {
    let bio: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Opening quote
            Image(systemName: "quote.opening")
                .font(.title)
                .foregroundColor(.purple.opacity(0.6))
                .offset(y: -5)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(bio)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .lineSpacing(4)
            }
            
            // Closing quote
            Image(systemName: "quote.closing")
                .font(.title)
                .foregroundColor(.purple.opacity(0.6))
                .offset(y: 5)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct SongCard: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let isCurrent: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Song artwork / playing indicator
                ZStack {
                    if let url = URL(string: song.artImageUrl), !song.artImageUrl.isEmpty {
                        // Show artwork when available
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure(_):
                                Color.gray.opacity(0.3)
                            default:
                                // Loading placeholder
                                Color.gray.opacity(0.15)
                            }
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isCurrent ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 2)
                        )
                        .shadow(radius: isPlaying ? 6 : 2)

                        // Overlay playing indicator or small index badge
                        if isPlaying {
                            Image(systemName: "waveform")
                                .font(.title3)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        } else {
                            Text("\(index)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                                .offset(x: 12, y: 12)
                        }
                    } else {
                        // Fallback when no artwork URL - square placeholder
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isPlaying ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)

                        if isPlaying {
                            Image(systemName: "waveform")
                                .font(.title3)
                                .foregroundColor(.white)
                        } else {
                            Text("\(index)")
                                .font(.headline)
                                .foregroundColor(isPlaying ? .white : .primary)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    // Song name
                    Text(song.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Artist
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    // Location with icon
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(song.location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Play button
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isCurrent ? Color.blue.opacity(0.5) : Color.clear,
                        lineWidth: 3
                    )
            )
            .shadow(color: .black.opacity(isCurrent ? 0.2 : 0.1), radius: isPlaying ? 12 : 4, y: isPlaying ? 6 : 2)
            .scaleEffect(isPlaying ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isPlaying)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Map Modal View
struct MapModalView: View {
    let songs: [Song]
    let startCoordinate: CLLocationCoordinate2D
    let endCoordinate: CLLocationCoordinate2D
    let startLocation: String
    let endLocation: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var position = MapCameraPosition.automatic
    @State private var isGeocoding = true
    @StateObject private var routeViewModel = RouteViewModel()
    
    let radiusInMeters: CLLocationDistance = 6000 // 6km radius
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) {
                    // Route polyline
                    if let route = routeViewModel.route {
                        MapPolyline(route.polyline)
                            .stroke(Color.blue, lineWidth: 5)
                    }
                    
                    // Start marker
                    Annotation("Start", coordinate: startCoordinate) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 40, height: 40)
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }
                    }
                    
                    // End marker
                    Annotation("End", coordinate: endCoordinate) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 40, height: 40)
                            Image(systemName: "flag.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        }
                    }
                    
                    // Song location markers with radius
                    ForEach(songs, id: \.id) { song in
                        let coordinate = CLLocationCoordinate2D(
                            latitude: song.latitude,
                            longitude: song.longitude
                        )
                        
                        // Radius circle (6km)
                        MapCircle(center: coordinate, radius: radiusInMeters)
                            .foregroundStyle(Color.blue.opacity(0.2))
                            .stroke(Color.blue, lineWidth: 2)
                        
                        // Pin annotation
                        Annotation(song.location, coordinate: coordinate) {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple)
                                        .frame(width: 36, height: 36)
                                    
                                    Text("\(songs.firstIndex(where: { $0.id == song.id }) ?? 0 + 1)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                                
                                Text(song.name)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                            }
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                
                // Loading overlay
                if isGeocoding {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading map...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .navigationTitle("Journey Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            updateMapRegion()
            routeViewModel.calculateRoute(from: startLocation, to: endLocation, transportType: .driving)
            // Hide loading immediately since we're using coordinates now
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isGeocoding = false
            }
        }
    }
    
    private func updateMapRegion() {
        // Calculate map region to show all points, including start/end and all songs
        var minLat = min(startCoordinate.latitude, endCoordinate.latitude)
        var maxLat = max(startCoordinate.latitude, endCoordinate.latitude)
        var minLon = min(startCoordinate.longitude, endCoordinate.longitude)
        var maxLon = max(startCoordinate.longitude, endCoordinate.longitude)
        
        for song in songs {
            let coordinate = CLLocationCoordinate2D(latitude: song.latitude, longitude: song.longitude)
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let latSpan = max(0.01, (maxLat - minLat) * 1.3)
        let lonSpan = max(0.01, (maxLon - minLon) * 1.3)
        
        let span = MKCoordinateSpan(
            latitudeDelta: latSpan,
            longitudeDelta: lonSpan
        )
        
        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}


//#Preview {
//    JourneyView(
//        songs: [
//            Song(id: "1", name: "Bohemian Rhapsody", artist: "Queen", location: "Baker Street, London"),
//            Song(id: "2", name: "Waterloo Sunset", artist: "The Kinks", location: "Waterloo Bridge, London"),
//            Song(id: "3", name: "London Calling", artist: "The Clash", location: "Westminster, London"),
//            Song(id: "4", name: "A Day in the Life", artist: "The Beatles", location: "Piccadilly Circus, London")
//        ],
//        startLocation: "Baker Street",
//        endLocation: "Kings Cross"
//    )
//}
