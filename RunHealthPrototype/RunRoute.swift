import Foundation
import CoreLocation

struct RunRoute {
    let workoutID: UUID
    let points: [RunRoutePoint]

    var coordinates: [CLLocationCoordinate2D] {
        points.map { $0.coordinate }
    }
}

struct RunRoutePoint: Identifiable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let altitude: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
