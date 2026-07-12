import CoreLocation
import Foundation

struct RunRoute: Identifiable, Sendable {
    let workoutID: UUID
    let points: [RunRoutePoint]
    let coordinates: [CLLocationCoordinate2D]

    init(
        workoutID: UUID,
        points: [RunRoutePoint],
        coordinates: [CLLocationCoordinate2D]? = nil
    ) {
        self.workoutID = workoutID
        self.points = points
        self.coordinates = coordinates ?? points.map(\.coordinate)
    }

    var id: UUID {
        workoutID
    }
}

struct RunRoutePoint: Identifiable, Sendable {
    let id = UUID()
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let altitude: Double?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
