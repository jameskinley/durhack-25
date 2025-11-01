//
//  RouteOptionsView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI

struct RouteOptionsView: View {
    
    let startLocation: String
    let endLocation: String
    
    @State private var selectedTransport: TransportType = .driving
    @State private var selectedGenres: Set<String> = ["Any"]
    @State private var selectedDecades: Set<String> = ["Any"]
    
    enum TransportType: String, CaseIterable {
        case driving = "Driving"
        case transit = "Transit"
        
        var icon: String {
            switch self {
            case .driving: return "car.fill"
            case .transit: return "bus.fill"
            }
        }
    }
    
    let genres = ["Any", "Rock", "Pop", "Jazz", "Hip Hop", "Electronic", "Country", "R&B", "Classical", "Alternative"]
    let decades = ["Any", "1950s", "1960s", "1970s", "1980s", "1990s", "2000s", "2010s", "2020s"]
    
    var genreList: String {
        if selectedGenres.contains("Any") || selectedGenres.isEmpty {
            return "Any"
        }
        return Array(selectedGenres).sorted().joined(separator: ", ")
    }
    
    var decadeList: String {
        if selectedDecades.contains("Any") || selectedDecades.isEmpty {
            return "Any"
        }
        return Array(selectedDecades).sorted().joined(separator: ", ")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Transport Type Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Transport Type")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        ForEach(TransportType.allCases, id: \.self) { transport in
                            Button(action: {
                                selectedTransport = transport
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: transport.icon)
                                        .font(.system(size: 40))
                                    Text(transport.rawValue)
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(selectedTransport == transport ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedTransport == transport ? .white : .primary)
                                .cornerRadius(16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Genre Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Music Genre")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    FlowLayout(spacing: 12) {
                        ForEach(genres, id: \.self) { genre in
                            Button(action: {
                                toggleGenreSelection(genre)
                            }) {
                                Text(genre)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(selectedGenres.contains(genre) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedGenres.contains(genre) ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Decade Selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Time Period")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    FlowLayout(spacing: 12) {
                        ForEach(decades, id: \.self) { decade in
                            Button(action: {
                                toggleDecadeSelection(decade)
                            }) {
                                Text(decade)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(selectedDecades.contains(decade) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedDecades.contains(decade) ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Continue Button
                NavigationLink(destination: RouteView(
                    startLocation: startLocation,
                    endLocation: endLocation,
                    transportType: selectedTransport,
                    genres: genreList,
                    decades: decadeList
                )) {
                    Text("Show Route")
                        .font(.headline)
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .padding(.top, 20)
        }
        .navigationTitle("Route Options")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func toggleGenreSelection(_ genre: String) {
        if genre == "Any" {
            // If "Any" is selected, clear all and select "Any"
            selectedGenres = ["Any"]
        } else {
            // Remove "Any" if selecting a specific genre
            selectedGenres.remove("Any")
            
            if selectedGenres.contains(genre) {
                selectedGenres.remove(genre)
                // If nothing selected, default to "Any"
                if selectedGenres.isEmpty {
                    selectedGenres = ["Any"]
                }
            } else {
                selectedGenres.insert(genre)
            }
        }
    }
    
    private func toggleDecadeSelection(_ decade: String) {
        if decade == "Any" {
            // If "Any" is selected, clear all and select "Any"
            selectedDecades = ["Any"]
        } else {
            // Remove "Any" if selecting a specific decade
            selectedDecades.remove("Any")
            
            if selectedDecades.contains(decade) {
                selectedDecades.remove(decade)
                // If nothing selected, default to "Any"
                if selectedDecades.isEmpty {
                    selectedDecades = ["Any"]
                }
            } else {
                selectedDecades.insert(decade)
            }
        }
    }
}

// Flow Layout for wrapping pills
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var size: CGSize = .zero
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)
                
                if currentX + subviewSize.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, subviewSize.height)
                currentX += subviewSize.width + spacing
                size.width = max(size.width, currentX - spacing)
            }
            
            size.height = currentY + lineHeight
            self.size = size
            self.positions = positions
        }
    }
}

#Preview {
    NavigationStack {
        RouteOptionsView(startLocation: "123 Main St", endLocation: "456 Oak Ave")
    }
}
