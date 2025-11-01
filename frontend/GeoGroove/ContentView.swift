//
//  ContentView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI
import MapKit

struct ContentView: View {
    
    @StateObject private var locationManager = LocationManager()
    @State private var position = MapCameraPosition.automatic
    @State private var startPoint: String = ""
    @State private var endPoint: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Map(position: $position) {
                        UserAnnotation()
                    }
                    .mapControls {
                        MapUserLocationButton()
                    }
                }
                HStack {
                    Image(systemName: "location")
                    TextField("Start Point", text: $startPoint)
                        .autocorrectionDisabled()
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(radius: 0.5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(20)
                .presentationDetents([.height(200), .large])
                .presentationBackground(.regularMaterial)
                .presentationBackgroundInteraction(.enabled(upThrough: .large))
            }
            .onAppear {
                locationManager.requestAuthorization()
            }
            .onChange(of: locationManager.lastLocation) { oldValue, newValue in
                if let location = newValue, oldValue == nil {
                    centerOnUser()
                }
            }
        }
    }
    
    private func centerOnUser() {
        guard let userLocation = locationManager.lastLocation else {
            return
        }
        
        let region = MKCoordinateRegion(
            center: userLocation.coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        
        position = .region(region)
    }
}

#Preview {
    ContentView()
}
