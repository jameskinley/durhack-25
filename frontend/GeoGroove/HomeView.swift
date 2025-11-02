//
//  HomeView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var auth = SpotifyAuthManager.shared
    @State private var showPlayAlert: Bool = false
    @State private var playAlertMessage: String = ""

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
                        // Start Spotify auth flow
                        auth.startAuthentication { success in
                            DispatchQueue.main.async {
                                print("Spotify auth completed: \(success)")
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green.opacity(0.12))
                                    .frame(width: 56, height: 56)
                                Image(systemName: auth.isConnected ? "checkmark.circle.fill" : "bolt.horizontal.circle")
                                    .font(.title2)
                                    .foregroundColor(auth.isConnected ? .green : .accentColor)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(auth.isConnected ? "Spotify connected" : "Connect to Spotify")
                                    .font(.headline)
                                Text(auth.isConnected ? "You're ready to import playlists" : "Sign in to enable streaming & sync")
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

                    // Test Spotify SDK / Web API - Play Rick Astley
                    Button(action: {
                        // Rick Astley - Never Gonna Give You Up
                        let rickURI = "spotify:track:4uLU6hMCjMI75M1A2tKUQC"
                        auth.play(trackURI: rickURI) { success, message in
                            DispatchQueue.main.async {
                                if success {
                                    playAlertMessage = "Playback started (or queued) on your active Spotify device."
                                } else {
                                    playAlertMessage = message ?? "Playback failed"
                                }
                                showPlayAlert = true
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple.opacity(0.12))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "play.rectangle.fill")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Test Spotify")
                                    .font(.headline)
                                Text("Play 'Never Gonna Give You Up'")
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
                    .disabled(!auth.isConnected)
                    .opacity(auth.isConnected ? 1.0 : 0.55)

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
                    .disabled(!auth.isConnected)
                    .opacity(auth.isConnected ? 1.0 : 0.55)
                    
                    // Recent Journeys
                    NavigationLink(destination: RecentJourneysView()
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
                    .disabled(!auth.isConnected)
                    .opacity(auth.isConnected ? 1.0 : 0.55)
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
            .alert(isPresented: $showPlayAlert) {
                Alert(title: Text("Spotify Test"), message: Text(playAlertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
}

#Preview {
    HomeView()
}
