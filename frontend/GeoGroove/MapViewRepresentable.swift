//
//  MapViewRepresentable.swift
//  GeoGroove
//
//  Created by Alex on 01/11/2025.
//

import Foundation
import SwiftUI
import MapKit
import Combine

final class MapModel: NSObject, ObservableObject {
    enum EditMode {
        case none, start, end
    }

    @Published var editMode: EditMode = .none
    @Published var startCoordinate: CLLocationCoordinate2D?
    @Published var endCoordinate: CLLocationCoordinate2D?
    @Published var currentRoute: MKRoute?

    // Made non-private so other types can access lastLocation for initial region
    let locationManager = LocationManager()

    weak var mapView: MKMapView?

    var startDescription: String {
        guard let c = startCoordinate else { return "Not set" }
        return String(format: "%.5f, %.5f", c.latitude, c.longitude)
    }

    var endDescription: String {
        guard let c = endCoordinate else { return "Not set" }
        return String(format: "%.5f, %.5f", c.latitude, c.longitude)
    }

    func requestLocationAuthorization() {
        locationManager.requestAuthorization()
    }

    func setCoordinate(_ coordinate: CLLocationCoordinate2D) {
        switch editMode {
        case .start:
            startCoordinate = coordinate
            addAnnotation(at: coordinate, title: "Start")
        case .end:
            endCoordinate = coordinate
            addAnnotation(at: coordinate, title: "End")
        case .none:
            break
        }
    }

    private func addAnnotation(at coordinate: CLLocationCoordinate2D, title: String) {
        guard let mapView = mapView else { return }
        let existing = mapView.annotations.first { ($0.title ?? "") == title }
        if let e = existing { mapView.removeAnnotation(e) }

        let ann = MKPointAnnotation()
        ann.coordinate = coordinate
        ann.title = title
        mapView.addAnnotation(ann)

        if let start = startCoordinate, let end = endCoordinate {
            let rect = MKMapRect.between(start, end).insetBy(dx: -20000, dy: -20000)
            mapView.setVisibleMapRect(rect, edgePadding: .init(top: 80, left: 20, bottom: 80, right: 20), animated: true)
        } else {
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
            mapView.setRegion(region, animated: true)
        }
    }

    func requestTransitRoute() {
        guard let start = startCoordinate, let end = endCoordinate, let mapView = mapView else { return }

        mapView.removeOverlays(mapView.overlays)
        currentRoute = nil

        let startPlacemark = MKPlacemark(coordinate: start)
        let endPlacemark = MKPlacemark(coordinate: end)

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: startPlacemark)
        request.destination = MKMapItem(placemark: endPlacemark)
        request.transportType = .transit
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.currentRoute = route
                    mapView.addOverlay(route.polyline)
                    mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: .init(top: 120, left: 20, bottom: 120, right: 20), animated: true)
                }
            } else {
                print("Transit route not found or error: \(String(describing: error))")
            }
        }
    }
}

struct MapViewRepresentable: UIViewRepresentable {
    @ObservedObject var model: MapModel

    func makeCoordinator() -> Coordinator {
        Coordinator(self, model: model)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        model.mapView = mapView
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapTapped(_:)))
        mapView.addGestureRecognizer(tap)

        // Use model.locationManager.lastLocation (now accessible)
        if let loc = model.locationManager.lastLocation {
            let region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
            mapView.setRegion(region, animated: false)
        }

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // No-op
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        let parent: MapViewRepresentable
        let model: MapModel

        init(_ parent: MapViewRepresentable, model: MapModel) {
            self.parent = parent
            self.model = model
            super.init()
        }

        @objc func mapTapped(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let mapView = model.mapView else { return }
            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            model.setCoordinate(coordinate)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: poly)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 6
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            let id = "pin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKPinAnnotationView
            if view == nil {
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: id)
                view?.canShowCallout = true
            } else {
                view?.annotation = annotation
            }

            if annotation.title == "Start" {
                view?.pinTintColor = .systemGreen
            } else if annotation.title == "End" {
                view?.pinTintColor = .systemRed
            } else {
                view?.pinTintColor = .systemBlue
            }

            return view
        }
    }
}

// Helper to compute MKMapRect between two coordinates
private extension MKMapRect {
    static func between(_ c1: CLLocationCoordinate2D, _ c2: CLLocationCoordinate2D) -> MKMapRect {
        let p1 = MKMapPoint(c1)
        let p2 = MKMapPoint(c2)
        let minX = min(p1.x, p2.x)
        let minY = min(p1.y, p2.y)
        let maxX = max(p1.x, p2.x)
        let maxY = max(p1.y, p2.y)
        return MKMapRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private extension MKMapRect {
    func insetBy(dx: Double, dy: Double) -> MKMapRect {
        return MKMapRect(x: self.origin.x - dx, y: self.origin.y - dy, width: self.size.width + dx * 2, height: self.size.height + dy * 2)
    }
}

