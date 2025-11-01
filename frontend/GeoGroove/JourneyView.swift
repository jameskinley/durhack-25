//
//  JourneyView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI

struct JourneyView: View {
    
    let songs: [Song]
    let startLocation: String
    let endLocation: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentlyPlaying: String?
    
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
                
                VStack(spacing: 0) {
                    // Header Card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "map.fill")
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
                    
                    // Songs List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                                SongCard(
                                    song: song,
                                    index: index + 1,
                                    isPlaying: currentlyPlaying == song.id,
                                    onTap: {
                                        currentlyPlaying = currentlyPlaying == song.id ? nil : song.id
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
                
                // Play All Button
                VStack {
                    Spacer()
                    
                    Button(action: {
                        // TODO: Start playback of all songs
                        print("Playing all songs in order")
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Play Journey")
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
                    .padding(.horizontal, 20)
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
            }
        }
    }
}

struct SongCard: View {
    let song: Song
    let index: Int
    let isPlaying: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Song number / playing indicator
                ZStack {
                    Circle()
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
            .shadow(color: .black.opacity(0.1), radius: isPlaying ? 12 : 4, y: isPlaying ? 6 : 2)
            .scaleEffect(isPlaying ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isPlaying)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    JourneyView(
        songs: [
            Song(id: "1", name: "Bohemian Rhapsody", artist: "Queen", location: "Baker Street, London"),
            Song(id: "2", name: "Waterloo Sunset", artist: "The Kinks", location: "Waterloo Bridge, London"),
            Song(id: "3", name: "London Calling", artist: "The Clash", location: "Westminster, London"),
            Song(id: "4", name: "A Day in the Life", artist: "The Beatles", location: "Piccadilly Circus, London")
        ],
        startLocation: "Baker Street",
        endLocation: "Kings Cross"
    )
}
