//
//  LoadingJourneyView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI
import CoreLocation

struct LoadingJourneyView: View {
    
    let startLocation: String
    let endLocation: String
    let startCoordinate: CLLocationCoordinate2D
    let endCoordinate: CLLocationCoordinate2D
    let transportType: RouteOptionsView.TransportType
    let genres: String
    let decades: String
    
    @State private var isAnimating = false
    @State private var showSongs = false
    @State private var songs: [Song] = []
    
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
        print("🎵 Starting to fetch songs...")
        
        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            
            /* 
            // TODO: Replace with actual API call
            let apiURL = URL(string: "https://your-api.com/songs")!
            var request = URLRequest(url: apiURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "start": startLocation,
                "end": endLocation,
                "transport": transportType.rawValue,
                "genres": genres,
                "decades": decades
            ]
            
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data {
                    // Parse response
                    let decoder = JSONDecoder()
                    if let songResponse = try? decoder.decode([Song].self, from: data) {
                        DispatchQueue.main.async {
                            self.songs = songResponse
                            self.showSongs = true
                        }
                    }
                }
            }.resume()
            */
            
            // Using dummy data for now
            print("🎵 Loading dummy data...")
            self.songs = self.generateDummySongs()
            print("🎵 Generated \(self.songs.count) songs")
            print("🎵 Setting showSongs to true...")
            self.showSongs = true
            print("🎵 showSongs is now: \(self.showSongs)")
        }
    }
    
    private func generateDummySongs() -> [Song] {
        return [
            Song(
                id: "1",
                name: "Bohemian Rhapsody",
                artist: "Queen",
                location: "Baker Street, London",
                bio: "\"This iconic six-minute opus was recorded at various studios across London in 1975. The operatic section features multi-tracked harmonies that took weeks to perfect. Freddie Mercury's vision for this genre-defying masterpiece changed rock music forever. Legend has it that the band recorded over 180 vocal overdubs, pushing the studio's 24-track tape machines to their absolute limits.\"",
                latitude: 51.5237,
                longitude: -0.1585
            ),
            Song(
                id: "2",
                name: "Waterloo Sunset",
                artist: "The Kinks",
                location: "Waterloo Bridge, London",
                bio: "\"Ray Davies penned this melancholic love letter to London while recovering from illness in 1966. The song captures the bittersweet beauty of watching lovers meet at Waterloo Station as the sun sets over the Thames. Davies has called it his favourite Kinks composition, describing it as 'the most beautiful song in the English language.'\"",
                latitude: 51.5081,
                longitude: -0.1169
            ),
            Song(
                id: "3",
                name: "London Calling",
                artist: "The Clash",
                location: "Westminster, London",
                bio: "\"The title track from The Clash's groundbreaking 1979 double album addressed social upheaval, nuclear anxiety, and cultural decay. Joe Strummer's urgent vocals and Mick Jones's driving guitar created a punk anthem that transcended the genre. The song's apocalyptic imagery reflected the band's view of London in the late 1970s, yet remains timelessly relevant.\"",
                latitude: 51.5007,
                longitude: -0.1246
            ),
            Song(
                id: "4",
                name: "A Day in the Life",
                artist: "The Beatles",
                location: "Piccadilly Circus, London",
                bio: "\"This psychedelic masterpiece closed Sgt. Pepper's Lonely Hearts Club Band with an orchestral crescendo that redefined pop music's possibilities. Lennon and McCartney's contrasting sections merged seamlessly, while the famous orchestral build-up required a 40-piece orchestra. Producer George Martin later called it 'the most ambitious and innovative recording The Beatles ever made.'\"",
                latitude: 51.5099,
                longitude: -0.1342
            ),
            Song(
                id: "5",
                name: "Parklife",
                artist: "Blur",
                location: "Hyde Park, London",
                bio: "\"Damon Albarn's witty observation of British leisure culture became the anthem of 1990s Britpop. Actor Phil Daniels's cockney narration added authentic London flavour to this celebration of everyday moments. The song perfectly captured the zeitgeist of mid-90s Britain, when the nation briefly fell in love with itself again through music, fashion, and cultural pride.\"",
                latitude: 51.5074,
                longitude: -0.1657
            ),
            Song(
                id: "6",
                name: "Common People",
                artist: "Pulp",
                location: "Ladbroke Grove, London",
                bio: "\"Jarvis Cocker's scathing critique of class tourism in Britain struck a chord with millions in 1995. The song tells the true story of a Greek art student he met at Central Saint Martins who wanted to 'live like common people.' Its razor-sharp social commentary and anthemic chorus made it one of the defining songs of the Britpop era.\"",
                latitude: 51.5171,
                longitude: -0.2068
            ),
            Song(
                id: "7",
                name: "River Deep Mountain High",
                artist: "Ike & Tina Turner",
                location: "Southbank, London",
                bio: "\"Phil Spector's 'Wall of Sound' production reached its zenith with this 1966 recording, which he called his greatest achievement. Tina Turner's powerhouse vocals soared over layers of orchestration in what Spector considered his magnum opus. Though initially overlooked in America, British audiences embraced it, launching the Turners to international stardom from their London performances.\"",
                latitude: 51.5076,
                longitude: -0.0994
            ),
            Song(
                id: "8",
                name: "God Save the Queen",
                artist: "Sex Pistols",
                location: "Camden Town, London",
                bio: "\"Released during the Queen's Silver Jubilee in 1977, this controversial punk anthem challenged British patriotism and monarchy. The BBC banned it, yet it still reached number one despite being censored from official charts. Johnny Rotten's sneering delivery and the song's raw energy embodied punk's rejection of establishment values, forever changing British music culture.\"",
                latitude: 51.5390,
                longitude: -0.1426
            )
        ]
    }
}

// Song data model
struct Song: Identifiable, Codable {
    let id: String
    let name: String
    let artist: String
    let location: String
    let bio: String
    let latitude: Double
    let longitude: Double
}

#Preview {
    NavigationStack {
        LoadingJourneyView(
            startLocation: "Baker Street",
            endLocation: "Kings Cross",
            startCoordinate: CLLocationCoordinate2D(latitude: 51.5237, longitude: -0.1585),
            endCoordinate: CLLocationCoordinate2D(latitude: 51.5308, longitude: -0.1238),
            transportType: .driving,
            genres: "Rock",
            decades: "1980s"
        )
    }
}
