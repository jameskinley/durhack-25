//
//  EndPointView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI
import MapKit

struct EndPointView: View {
    
    let startLocation: String
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var addressSearch = AddressSearchViewModel()
    @State private var position = MapCameraPosition.automatic
    @State private var showingSuggestions = false
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $position) {
                    UserAnnotation()
                }
                .mapControls {
                    MapUserLocationButton()
                }
            }
            
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "flag.fill")
                    TextField("End Point", text: $addressSearch.searchQuery)
                        .autocorrectionDisabled()
                        .padding()
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
                    
                    Button(action: {
                        // TODO: Navigate to route planning or confirmation
                        print("Start: \(startLocation), End: \(addressSearch.searchQuery)")
                    }) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.green)
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
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 20)
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .padding(.horizontal, 20)
                }
            }
            .presentationDetents([.height(200), .large])
            .presentationBackground(.regularMaterial)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .padding(.bottom, 20)
        }
        .navigationTitle("End")
        .navigationBarTitleDisplayMode(.inline)
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
    
    private func selectAddress(_ completion: MKLocalSearchCompletion) {
        addressSearch.selectLocation(completion) { coordinate in
            if let coordinate = coordinate {
                // Update the text field with selected address
                addressSearch.searchQuery = completion.title
                showingSuggestions = false
                
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
        EndPointView(startLocation: "123 Main St")
    }
}
