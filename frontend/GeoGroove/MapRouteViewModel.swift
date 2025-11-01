import Foundation
import MapKit
import SwiftUI
import CoreLocation
import Combine

@MainActor
final class MapRouteViewModel: NSObject, ObservableObject {
    // Inputs
    @Published var fromQuery: String = ""
    @Published var toQuery: String = ""

    enum Transport: CaseIterable {
        case driving, walking, transit

        var title: String {
            switch self {
            case .driving: return "Drive"
            case .walking: return "Walk"
            case .transit:  return "Transit"
            }
        }

        var mkType: MKDirectionsTransportType {
            switch self {
            case .driving: return .automobile
            case .walking: return .walking
            case .transit: return .transit
            }
        }

        var launchMode: String {
            switch self {
            case .driving: return MKLaunchOptionsDirectionsModeDriving
            case .walking: return MKLaunchOptionsDirectionsModeWalking
            case .transit: return MKLaunchOptionsDirectionsModeTransit
            }
        }
    }
    @Published var transport: Transport = .driving
    @Published var avoidHighways = false
    @Published var avoidTolls = false

    // Map state
    @Published var currentRoute: MKRoute?
    @Published var startCoordinate: CLLocationCoordinate2D?
    @Published var endCoordinate: CLLocationCoordinate2D?
    @Published var cameraPosition: MapCameraPosition = .automatic

    // UI state
    @Published var isCalculating = false

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    // Permissions
    func requestLocationAuthorization() async {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            break
        }
        locationManager.startUpdatingLocation()
    }

    func centerOnUser() {
        if let coordinate = locationManager.location?.coordinate {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                )
            )
        }
    }

    // Derived
    var routeSummary: (distance: String, eta: String)? {
        guard let route = currentRoute else { return nil }
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .naturalScale
        let km = Measurement(value: route.distance / 1000.0, unit: UnitLength.kilometers)
        let distance = formatter.string(from: km)

        let eta = DateComponentsFormatter()
        eta.allowedUnits = [.hour, .minute]
        eta.unitsStyle = .short
        let etaString = eta.string(from: route.expectedTravelTime) ?? "-"
        return (distance: distance, eta: etaString)
    }

    // Main action
    func calculateRoute() async {
        isCalculating = true
        defer { isCalculating = false }

        do {
            let sourceItem = try await mapItem(for: fromQuery, fallbackToUserLocation: true)
            let destItem = try await mapItem(for: toQuery, fallbackToUserLocation: false)

            startCoordinate = sourceItem.placemark.coordinate
            endCoordinate = destItem.placemark.coordinate

            let req = MKDirections.Request()
            req.source = sourceItem
            req.destination = destItem
            req.transportType = transport.mkType
            req.requestsAlternateRoutes = false
            req.departureDate = Date()

            let directions = MKDirections(request: req)
            let response = try await directions.calculate()
            guard let route = response.routes.first else { return }

            currentRoute = route

            // Fit camera to route
            let rect = route.polyline.boundingMapRect.insetBy(dx: -2000, dy: -2000)
            let region = MKCoordinateRegion(rect)
            cameraPosition = .region(region)
        } catch {
            print("Routing failed: \(error)")
        }
    }

    func swapEndpoints() {
        (fromQuery, toQuery) = (toQuery, fromQuery)
        (startCoordinate, endCoordinate) = (endCoordinate, startCoordinate)
    }

    func openInAppleMaps() {
        guard let start = startCoordinate, let end = endCoordinate else { return }
        let startItem = MKMapItem(placemark: MKPlacemark(coordinate: start))
        let endItem = MKMapItem(placemark: MKPlacemark(coordinate: end))

        var options: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: transport.launchMode,
            MKLaunchOptionsShowsTrafficKey: true
        ]

        MKMapItem.openMaps(with: [startItem, endItem], launchOptions: options)
    }

    // Helpers
    private func mapItem(for query: String, fallbackToUserLocation: Bool) async throws -> MKMapItem {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if fallbackToUserLocation, let location = locationManager.location {
                return MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
            } else {
                throw RoutingError.invalidQuery
            }
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = .address
        if let user = locationManager.location {
            request.region = MKCoordinateRegion(
                center: user.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
            )
        }

        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        if let first = response.mapItems.first {
            return first
        } else {
            throw RoutingError.placeNotFound
        }
    }

    enum RoutingError: Error {
        case invalidQuery
        case placeNotFound
    }
}

extension MapRouteViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            centerOnUser()
        default:
            break
        }
    }
}
