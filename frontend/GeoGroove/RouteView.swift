//
//  RouteView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI
import MapKit
import Combine

struct RouteView: View {
    
    let startLocation: String
    let endLocation: String
    let transportType: RouteOptionsView.TransportType
    let genres: String
    let decades: String
    
    @StateObject private var routeViewModel = RouteViewModel()
    @State private var position = MapCameraPosition.automatic
    
    var body: some View {
        VStack(spacing: 0) {
            // Map View
            Map(position: $position) {
                // Start marker
                if let startCoord = routeViewModel.startCoordinate {
                    Annotation("Start", coordinate: startCoord) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 30, height: 30)
                            Image(systemName: "play.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                        }
                    }
                }
                
                // End marker
                if let endCoord = routeViewModel.endCoordinate {
                    Annotation("End", coordinate: endCoord) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 30, height: 30)
                            Image(systemName: "flag.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 12))
                        }
                    }
                }
                
                // Route polyline
                if let route = routeViewModel.route {
                    MapPolyline(route.polyline)
                        .stroke(Color.blue, lineWidth: 5)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            
            // Route Info Card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Route Details")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: transportType == .driving ? "car.fill" : "bus.fill")
                            Text(transportType.rawValue)
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        if let route = routeViewModel.route {
                            HStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "clock")
                                    Text(formatDuration(route.expectedTravelTime))
                                }
                                
                                HStack {
                                    Image(systemName: "map")
                                    Text(formatDistance(route.distance))
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if genres != "Any" {
                            Text(genres)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(12)
                        }
                        
                        if decades != "Any" {
                            Text(decades)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(12)
                        }
                    }
                }
                
                if routeViewModel.isLoading {
                    ProgressView("Calculating route...")
                } else if routeViewModel.errorMessage != nil {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(routeViewModel.errorMessage ?? "Unknown error")
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
                
                // Start Journey Button
                Button(action: {
                    // TODO: Start navigation or music playback
                    print("Starting journey with \(genres) from \(decades)")
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Journey")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
            }
            .padding(20)
            .background(Color(UIColor.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
        }
        .navigationTitle("Your Route")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            routeViewModel.calculateRoute(
                from: startLocation,
                to: endLocation,
                transportType: transportType
            )
        }
        .onChange(of: routeViewModel.route) { oldValue, newValue in
            if let route = newValue {
                // Center map on route
                let rect = route.polyline.boundingMapRect
                position = .rect(MKMapRect(
                    origin: MKMapPoint(x: rect.origin.x - rect.size.width * 0.1, y: rect.origin.y - rect.size.height * 0.1),
                    size: MKMapSize(width: rect.size.width * 1.2, height: rect.size.height * 1.2)
                ))
            }
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let kilometers = meters / 1000
        if kilometers < 1 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", kilometers)
        }
    }
}

// ViewModel to handle route calculation
class RouteViewModel: ObservableObject {
    @Published var route: MKRoute?
    @Published var startCoordinate: CLLocationCoordinate2D?
    @Published var endCoordinate: CLLocationCoordinate2D?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func calculateRoute(from start: String, to end: String, transportType: RouteOptionsView.TransportType) {
        isLoading = true
        errorMessage = nil
        
        // Geocode start location
        geocodeAddress(start) { [weak self] startCoord in
            guard let self = self, let startCoord = startCoord else {
                self?.errorMessage = "Could not find start location"
                self?.isLoading = false
                return
            }
            
            self.startCoordinate = startCoord
            
            // Geocode end location
            self.geocodeAddress(end) { [weak self] endCoord in
                guard let self = self, let endCoord = endCoord else {
                    self?.errorMessage = "Could not find end location"
                    self?.isLoading = false
                    return
                }
                
                self.endCoordinate = endCoord
                
                // Calculate route
                self.requestRoute(from: startCoord, to: endCoord, transportType: transportType)
            }
        }
    }
    
    private func geocodeAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            if let coordinate = placemarks?.first?.location?.coordinate {
                completion(coordinate)
            } else {
                completion(nil)
            }
        }
    }
    
    private func requestRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, transportType: RouteOptionsView.TransportType) {
        let startPlacemark = MKPlacemark(coordinate: start)
        let endPlacemark = MKPlacemark(coordinate: end)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: startPlacemark)
        request.destination = MKMapItem(placemark: endPlacemark)
        
        // For transit, try walking first as MapKit transit is unreliable
        // In a real app, you'd use a transit API like Google Directions or TfL
        if transportType == .transit {
            print("🚦 Transit requested - using walking as fallback (MapKit transit is limited)")
            request.transportType = .walking
        } else {
            request.transportType = .automobile
        }
        
        request.requestsAlternateRoutes = false
        
        print("🚦 Requesting \(transportType.rawValue) route from \(start) to \(end)")
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    let nsError = error as NSError
                    print("❌ Route error: \(error.localizedDescription)")
                    print("   Domain: \(nsError.domain), Code: \(nsError.code)")
                    print("   UserInfo: \(nsError.userInfo)")
                }
                
                if let route = response?.routes.first {
                    print("✅ Route found: \(route.distance)m, \(route.expectedTravelTime)s")
                    self?.route = route
                    
                    // Show note if we used walking instead of transit
                    if transportType == .transit {
                        self?.errorMessage = "Note: Showing walking route (MapKit transit API is limited). Use for approximate distance/time."
                    }
                } else if let routes = response?.routes {
                    print("⚠️ Got response but no routes. Total routes: \(routes.count)")
                    self?.errorMessage = "No \(transportType.rawValue.lowercased()) route available for this location"
                } else {
                    print("❌ No response received")
                    self?.errorMessage = error?.localizedDescription ?? "No route found. Try a different transport type."
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RouteView(
            startLocation: "123 Main St",
            endLocation: "456 Oak Ave",
            transportType: .driving,
            genres: "Rock",
            decades: "1980s"
        )
    }
}
