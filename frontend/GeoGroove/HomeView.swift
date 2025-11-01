//
//  HomeView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI

struct HomeView: View {
    @State private var spotifyConnected: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 5)

                // App Title / Logo
                VStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    Text("GeoGroove")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Spacer(minLength: 5)
                // Cards
                VStack(spacing: 20) {

                    // Connect to Spotify
                    Button(action: {
                        // Placeholder connect action – toggle state for now
                        spotifyConnected.toggle()
                        print("Spotify connected: \(spotifyConnected)")
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.12))
                                    .frame(width: 56, height: 56)
                                Image(systemName: spotifyConnected ? "checkmark.circle.fill" : "bolt.horizontal.circle")
                                    .font(.title2)
                                    .foregroundColor(spotifyConnected ? .green : .accentColor)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(spotifyConnected ? "Spotify connected" : "Connect to Spotify")
                                    .font(.headline)
                                Text(spotifyConnected ? "You're ready to import playlists" : "Sign in to enable streaming & sync")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.secondarySystemGroupedBackground)))
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                    }

                    // Start New Journey
                    NavigationLink(destination: MapView()) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.14)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "paperplane.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start a new journey")
                                    .font(.headline)
                                Text("Pick start & end points and curate your soundtrack")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.secondarySystemGroupedBackground)))
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                    }
                    // Disabled until Spotify is connected
                    .disabled(!spotifyConnected)
                    .opacity(spotifyConnected ? 1.0 : 0.55)
                    
                    // Recent Journeys
                    NavigationLink(destination: Text("Recent journeys will appear here.")
                        .navigationTitle("Recent Journeys")) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Recent journeys")
                                    .font(.headline)
                                Text("See your past routes and playlists")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(UIColor.secondarySystemGroupedBackground)))
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
                    }
                    // Disabled until Spotify is connected
                    .disabled(!spotifyConnected)
                    .opacity(spotifyConnected ? 1.0 : 0.55)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.06),
                        Color.purple.opacity(0.06)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    HomeView()
}
