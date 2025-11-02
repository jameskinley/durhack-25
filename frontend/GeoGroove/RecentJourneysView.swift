import SwiftUI

struct RecentJourneysView: View {
    @State private var journeys: [JourneyRecord] = []
    @State private var showCleared = false

    var body: some View {
        VStack {
            if journeys.isEmpty {
                VStack(spacing: 12) {
                    Text("No recent journeys")
                        .font(.headline)
                    Text("Complete a journey to see it listed here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(journeys) { j in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(j.startLocation) → \(j.endLocation)")
                                    .font(.headline)
                                Spacer()
                                Text(shortDate(j.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 12) {
                                Text("Songs: \(j.songCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("Duration: \(formatDuration(j.duration))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !journeys.isEmpty {
                    Button("Clear") {
                        RecentJourneysStore.clearAll()
                        journeys = []
                        showCleared = true
                    }
                }
            }
        }
        .onAppear(perform: load)
        .alert("Cleared", isPresented: $showCleared) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Recent journeys cleared.")
        }
    }

    private func load() {
        journeys = RecentJourneysStore.loadAll()
    }

    private func delete(at offsets: IndexSet) {
        RecentJourneysStore.remove(at: offsets)
        load()
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: d)
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let seconds = Int(s)
        let mins = seconds / 60
        let hrs = mins / 60
        let remMins = mins % 60
        if hrs > 0 {
            return "\(hrs)h \(remMins)m"
        } else {
            return "\(remMins)m"
        }
    }
}

#Preview {
    NavigationStack {
        RecentJourneysView()
    }
}
