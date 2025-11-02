//
//  MapView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI
import MapKit

struct MapView: View {
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var addressSearch = AddressSearchViewModel()
    @State private var position = MapCameraPosition.automatic
    @State private var endPoint: String = ""
    @State private var showingSuggestions = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $position) {
                    UserAnnotation()
                    
                    // Show pin for selected start location
                    if let coordinate = selectedCoordinate {
                        Annotation("Start", coordinate: coordinate) {
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 40, height: 40)
                                    .shadow(radius: 4)
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                            }
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                }
            }
            
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "location")
                    
                    ZStack(alignment: .trailing) {
                        TextField("Start Point", text: $addressSearch.searchQuery)
                            .autocorrectionDisabled()
                            .padding()
                            .padding(.trailing, addressSearch.searchQuery.isEmpty ? 0 : 30)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(radius: 0.5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: addressSearch.searchQuery) { oldValue, newValue in
                                showingSuggestions = !newValue.isEmpty
                            }
                        
                        if !addressSearch.searchQuery.isEmpty {
                            Button(action: {
                                addressSearch.searchQuery = ""
                                showingSuggestions = false
                                selectedCoordinate = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 12)
                            }
                        }
                    }
                    
                    NavigationLink(destination: EndPointView(startLocation: addressSearch.searchQuery)) {
                        Image(systemName: "arrow.right")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                }
                .padding(20)
                
                if showingSuggestions && !addressSearch.searchResults.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(addressSearch.searchResults, id: \.self) { result in
                                Button(action: {
                                    selectAddress(result)
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.title)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 24)
                                }
                                Divider()
                                    .padding(.horizontal, 24)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 200)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
                
                // OR divider and Use Current Location button
                VStack(spacing: 12) {
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        Text("OR")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.horizontal, 20)
                    
                    NavigationLink(destination: EndPointView(startLocation: "Current Location")) {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Use Current Location")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .padding(.horizontal, 20)
                    .simultaneousGesture(TapGesture().onEnded {
                        useCurrentLocation()
                    })
                }
                .padding(.bottom, 12)
            }
            .presentationDetents([.height(200), .large])
            .presentationBackground(.regularMaterial)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
        }
        
        .navigationTitle(Text("Start"))

        .onAppear {
            locationManager.requestAuthorization()
        }
        .onChange(of: locationManager.lastLocation) { oldValue, newValue in
            if let location = newValue, oldValue == nil {
                centerOnUser()
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
    
    private func useCurrentLocation() {
        guard let userLocation = locationManager.lastLocation else {
            print("User location not available")
            return
        }
        
        selectedCoordinate = userLocation.coordinate
        
        // Use reverse geocoding to get address from coordinates
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                let address = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                addressSearch.searchQuery = address.isEmpty ? "Current Location" : address
            } else {
                addressSearch.searchQuery = "Current Location"
            }
            showingSuggestions = false
        }
        
        centerOnUser()
    }
    
    private func selectAddress(_ completion: MKLocalSearchCompletion) {
        addressSearch.selectLocation(completion) { coordinate in
            if let coordinate = coordinate {
                // Update the text field with selected address
                addressSearch.searchQuery = completion.title
                showingSuggestions = false
                selectedCoordinate = coordinate
                
                // Center map on selected location
                let region = MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 1000,
                    longitudinalMeters: 1000
                )
                position = .region(region)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MapView()
    }
}
