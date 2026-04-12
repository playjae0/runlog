import MapKit
import SwiftUI

struct WorkoutRouteMapView: View {
    let workout: RunWorkout

    @State private var route: RunRoute?
    @State private var routeState: RouteState = .loading
    @State private var mapPosition: MapCameraPosition = .automatic

    private let healthKitService = HealthKitService()

    var body: some View {
        VStack(spacing: 12) {
            routeStatus

            Map(position: $mapPosition) {
                if let route {
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(.blue, lineWidth: 4)

                    if let first = route.coordinates.first {
                        Marker("Start", coordinate: first)
                    }

                    if let last = route.coordinates.last {
                        Marker("Finish", coordinate: last)
                    }
                }
            }
            .mapStyle(.standard)
        }
        .padding()
        .navigationTitle("Route")
        .task {
            await loadRoute()
        }
    }

    @ViewBuilder
    private var routeStatus: some View {
        switch routeState {
        case .loading:
            ProgressView("코스 좌표를 읽는 중입니다...")

        case .loaded(let pointCount):
            Text("코스 좌표 \(pointCount)개를 읽었습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .empty:
            Text("이 workout에는 표시할 코스 좌표가 없습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .failed(let message):
            Text("코스 읽기 실패: \(message)")
                .font(.subheadline)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private func loadRoute() async {
        routeState = .loading

        let result = await healthKitService.fetchRoute(for: workout.id)

        await MainActor.run {
            switch result {
            case .success(let route):
                self.route = route

                if route.points.isEmpty {
                    routeState = .empty
                } else {
                    routeState = .loaded(route.points.count)
                    mapPosition = .region(region(for: route.coordinates))
                }

            case .failure(let error):
                routeState = .failed(error.localizedDescription)
            }
        }
    }

    private func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion()
        }

        let bounds = coordinates.reduce(
            (
                minLatitude: first.latitude,
                maxLatitude: first.latitude,
                minLongitude: first.longitude,
                maxLongitude: first.longitude
            )
        ) { bounds, coordinate in
            (
                min(bounds.minLatitude, coordinate.latitude),
                max(bounds.maxLatitude, coordinate.latitude),
                min(bounds.minLongitude, coordinate.longitude),
                max(bounds.maxLongitude, coordinate.longitude)
            )
        }

        let latitudeDelta = max((bounds.maxLatitude - bounds.minLatitude) * 1.3, 0.005)
        let longitudeDelta = max((bounds.maxLongitude - bounds.minLongitude) * 1.3, 0.005)
        let center = CLLocationCoordinate2D(
            latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
            longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
        )

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeDelta,
                longitudeDelta: longitudeDelta
            )
        )
    }
}

private enum RouteState {
    case loading
    case loaded(Int)
    case empty
    case failed(String)
}
