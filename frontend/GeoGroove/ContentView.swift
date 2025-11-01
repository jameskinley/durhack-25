//
//  ContentView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI
import MapKit
import Combine

struct ContentView: View {
    
    @StateObject private var locationManager = LocationManager()
    @State private var position = MapCameraPosition.automatic
    @State private var startPoint: String = ""
    @State private var endPoint: String = ""
    @State private var isSheetPresented: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10){
                ZStack(alignment: .bottomTrailing) {
                    Map(position: $position)
                    Button {
                        centerOnUser()
                    } label: {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
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
        }
    }
    
    private func centerOnUser() {
        guard let userLocation = locationManager.lastLocation else {
            print("User location not available")
            return
        }
        
        let userCoordinate = userLocation.coordinate
        print(userCoordinate)
        let region = MKCoordinateRegion(
            center: userCoordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        
        position = .region(region)
    }
}

#Preview {
    ContentView()
}
