import CoreLocation
import GoogleMaps
import SwiftUI

struct GoogleMapView: UIViewRepresentable {
    let routes: [[CLLocationCoordinate2D]]
    let currentCoordinate: CLLocationCoordinate2D?
    let lineColor: UIColor
    let mapTheme: MapTheme
    let showsStartMarker: Bool
    let showsEndMarker: Bool
    var startCoordinate: CLLocationCoordinate2D? = nil
    var endCoordinate: CLLocationCoordinate2D? = nil
    var cameraFitRoutes: [[CLLocationCoordinate2D]]? = nil
    var isInteractionEnabled = true

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView(frame: .zero)
        mapView.isMyLocationEnabled = false
        mapView.settings.compassButton = true
        mapView.settings.rotateGestures = true
        mapView.settings.tiltGestures = false
        mapView.overrideUserInterfaceStyle = mapTheme.interfaceStyle
        mapView.backgroundColor = .clear
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        let coordinator = context.coordinator
        mapView.overrideUserInterfaceStyle = mapTheme.interfaceStyle
        mapView.isUserInteractionEnabled = isInteractionEnabled
        mapView.settings.scrollGestures = isInteractionEnabled
        mapView.settings.zoomGestures = isInteractionEnabled
        mapView.settings.rotateGestures = isInteractionEnabled
        mapView.settings.tiltGestures = false
        mapView.settings.compassButton = isInteractionEnabled

        let nonEmptyRoutes = routes.filter { !$0.isEmpty }
        coordinator.syncPolylines(
            on: mapView,
            routes: nonEmptyRoutes,
            lineColor: lineColor
        )

        coordinator.updateMarker(
            &coordinator.startMarker,
            on: mapView,
            title: "Start",
            coordinate: showsStartMarker ? (startCoordinate ?? nonEmptyRoutes.first?.first) : nil,
            tintColor: .systemGreen
        )
        coordinator.updateMarker(
            &coordinator.endMarker,
            on: mapView,
            title: "Finish",
            coordinate: showsEndMarker ? (endCoordinate ?? nonEmptyRoutes.last?.last) : nil,
            tintColor: .systemRed
        )
        coordinator.updateMarker(
            &coordinator.currentMarker,
            on: mapView,
            title: "Current",
            coordinate: currentCoordinate,
            tintColor: UIColor(RunTheme.accent)
        )

        let routesForCamera = (cameraFitRoutes ?? routes).filter { !$0.isEmpty }
        let shouldFitCamera = coordinator.shouldFitCamera(
            for: routesForCamera,
            currentCoordinate: currentCoordinate
        )

        guard shouldFitCamera else {
            return
        }

        let bounds = makeBounds(
            routes: routesForCamera,
            including: currentCoordinate
        )

        guard let bounds else {
            return
        }

        coordinator.lastFittedRoutes = routesForCamera
        coordinator.lastFittedCurrentCoordinate = currentCoordinate
        mapView.moveCamera(GMSCameraUpdate.fit(bounds, withPadding: 32))
    }

    private func makeBounds(
        routes: [[CLLocationCoordinate2D]],
        including currentCoordinate: CLLocationCoordinate2D?
    ) -> GMSCoordinateBounds? {
        var bounds: GMSCoordinateBounds?

        for route in routes {
            for coordinate in route {
                if bounds != nil {
                    bounds = bounds?.includingCoordinate(coordinate)
                } else {
                    bounds = GMSCoordinateBounds(coordinate: coordinate, coordinate: coordinate)
                }
            }
        }

        if let currentCoordinate {
            if bounds != nil {
                bounds = bounds?.includingCoordinate(currentCoordinate)
            } else {
                bounds = GMSCoordinateBounds(
                    coordinate: currentCoordinate,
                    coordinate: currentCoordinate
                )
            }
        }

        return bounds
    }
}

extension GoogleMapView {
    final class Coordinator {
        var polylines: [GMSPolyline] = []
        var renderedRoutes: [[CLLocationCoordinate2D]] = []
        var startMarker: GMSMarker?
        var endMarker: GMSMarker?
        var currentMarker: GMSMarker?
        var lastFittedRoutes: [[CLLocationCoordinate2D]] = []
        var lastFittedCurrentCoordinate: CLLocationCoordinate2D?

        func syncPolylines(
            on mapView: GMSMapView,
            routes: [[CLLocationCoordinate2D]],
            lineColor: UIColor
        ) {
            if routes.count < polylines.count {
                for polyline in polylines[routes.count...] {
                    polyline.map = nil
                }
                polylines.removeSubrange(routes.count...)
                renderedRoutes.removeSubrange(routes.count...)
            }

            for index in routes.indices {
                let route = routes[index]

                if polylines.indices.contains(index) {
                    guard !coordinatesMatch(renderedRoutes[index], route) else {
                        polylines[index].strokeColor = lineColor
                        continue
                    }

                    polylines[index].path = makePath(for: route)
                    polylines[index].strokeColor = lineColor
                    renderedRoutes[index] = route
                } else {
                    let polyline = GMSPolyline(path: makePath(for: route))
                    polyline.strokeColor = lineColor
                    polyline.strokeWidth = 5
                    polyline.map = mapView
                    polylines.append(polyline)
                    renderedRoutes.append(route)
                }
            }
        }

        func updateMarker(
            _ marker: inout GMSMarker?,
            on mapView: GMSMapView,
            title: String,
            coordinate: CLLocationCoordinate2D?,
            tintColor: UIColor
        ) {
            guard let coordinate else {
                marker?.map = nil
                marker = nil
                return
            }

            if let marker {
                marker.position = coordinate
                marker.map = mapView
                return
            }

            let newMarker = GMSMarker(position: coordinate)
            newMarker.title = title
            newMarker.icon = GMSMarker.markerImage(with: tintColor)
            newMarker.map = mapView
            marker = newMarker
        }

        func shouldFitCamera(
            for routes: [[CLLocationCoordinate2D]],
            currentCoordinate: CLLocationCoordinate2D?
        ) -> Bool {
            if !routes.isEmpty {
                return !routeSetsMatch(routes, lastFittedRoutes)
            }

            guard currentCoordinate != nil else {
                return false
            }

            return !coordinateMatches(currentCoordinate, lastFittedCurrentCoordinate)
        }

        private func makePath(for route: [CLLocationCoordinate2D]) -> GMSPath {
            let path = GMSMutablePath()
            for coordinate in route {
                path.add(coordinate)
            }
            return path
        }

        private func routeSetsMatch(
            _ lhs: [[CLLocationCoordinate2D]],
            _ rhs: [[CLLocationCoordinate2D]]
        ) -> Bool {
            guard lhs.count == rhs.count else {
                return false
            }

            for index in lhs.indices {
                guard coordinatesMatch(lhs[index], rhs[index]) else {
                    return false
                }
            }

            return true
        }

        private func coordinatesMatch(
            _ lhs: [CLLocationCoordinate2D],
            _ rhs: [CLLocationCoordinate2D]
        ) -> Bool {
            guard lhs.count == rhs.count else {
                return false
            }

            for index in lhs.indices {
                guard coordinateMatches(lhs[index], rhs[index]) else {
                    return false
                }
            }

            return true
        }

        private func coordinateMatches(
            _ lhs: CLLocationCoordinate2D?,
            _ rhs: CLLocationCoordinate2D?
        ) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none):
                return true
            case let (.some(lhsCoordinate), .some(rhsCoordinate)):
                return lhsCoordinate.latitude == rhsCoordinate.latitude &&
                    lhsCoordinate.longitude == rhsCoordinate.longitude
            default:
                return false
            }
        }
    }
}
