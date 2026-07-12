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

func normalizeRunRoutePoints(_ pointGroups: [[RunRoutePoint]]) -> [RunRoutePoint] {
    let indexedPoints = pointGroups
        .flatMap { $0 }
        .enumerated()
        .filter { _, point in
            CLLocationCoordinate2DIsValid(point.coordinate)
        }
        .sorted { lhs, rhs in
            if lhs.element.timestamp == rhs.element.timestamp {
                return lhs.offset < rhs.offset
            }

            return lhs.element.timestamp < rhs.element.timestamp
        }

    var seen = Set<RunRoutePointIdentity>()

    return indexedPoints.compactMap { _, point in
        let identity = RunRoutePointIdentity(
            timestamp: point.timestamp,
            latitude: point.latitude,
            longitude: point.longitude
        )

        guard seen.insert(identity).inserted else {
            return nil
        }

        return point
    }
}

private struct RunRoutePointIdentity: Hashable {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
}
