//
//  ContentView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject private var mapModel = MapModel()

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                MapViewRepresentable(model: mapModel)
                    .frame(height: geo.size.height * 0.60)
                    .edgesIgnoringSafeArea(.top)
            }

            Divider()

            VStack(spacing: 12) {
                HStack {
                    Button(action: { mapModel.editMode = .start }) {
                        Label(mapModel.startCoordinate == nil ? "Set Start" : "Edit Start",
                              systemImage: mapModel.startCoordinate == nil ? "mappin.and.ellipse" : "mappin")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { mapModel.editMode = .end }) {
                        Label(mapModel.endCoordinate == nil ? "Set End" : "Edit End",
                              systemImage: mapModel.endCoordinate == nil ? "mappin.and.ellipse" : "mappin")
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Button(action: mapModel.requestTransitRoute) {
                        Label("Show Transit Route", systemImage: "tram.fill")
                    }
                    .disabled(!(mapModel.startCoordinate != nil && mapModel.endCoordinate != nil))
                    .buttonStyle(.bordered)
                }

                HStack {
                    VStack(alignment: .leading) {
                        Text("Start")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(mapModel.startDescription)
                            .font(.subheadline)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("End")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(mapModel.endDescription)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }

                if let route = mapModel.currentRoute {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Route summary")
                            .font(.headline)

                        // Use an explicit String and ensure all quotes are straight quotes
                        Text(String(format: "Distance: %.1f km  •  Expected travel time: %d min",
                                    route.distance / 1000,
                                    Int(route.expectedTravelTime / 60)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(route.steps.indices, id: \.self) { idx in
                                    let step = route.steps[idx]
                                    HStack(alignment: .top) {
                                        Text("\(idx + 1).")
                                            .bold()
                                        Text(step.instructions)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 160)
                    }
                } else {
                    Text("Tap the map to set Start or End while the corresponding button is active. Then tap Show Transit Route.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding()
        }
        .onAppear {
            mapModel.requestLocationAuthorization()
        }
    }
}

#Preview {
    ContentView()
}
