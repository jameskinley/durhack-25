//
//  HomeView.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                // App Title or Logo
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)
                    
                    Text("GeoGroove")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // GO Button
                NavigationLink(destination: MapView()) {
                    Text("GO")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 60)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(30)
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                
                Spacer()
                    .frame(height: 100)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

#Preview {
    HomeView()
}
