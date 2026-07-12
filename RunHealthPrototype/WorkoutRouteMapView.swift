import MapKit
import SwiftUI

struct WorkoutRouteMapView: View {
    @AppStorage(MapTheme.storageKey) private var selectedMapThemeRawValue = MapTheme.system.rawValue
    let workout: RunWorkout

    @State private var route: RunRoute?
    @State private var routeState: RouteState = .loading
    @State private var mapPosition: MapCameraPosition = .automatic

    private let healthKitService = HealthKitService()

    private var selectedMapTheme: MapTheme {
        MapTheme(rawValue: selectedMapThemeRawValue) ?? .system
    }

    var body: some View {
        VStack(spacing: 14) {
            routeStatus
            routeMap
        }
        .padding(RunTheme.pagePadding)
        .background(RunTheme.screenBackground)
        .navigationTitle("Route")
        .animation(RunTheme.smoothAnimation, value: routeState)
        .task {
            await loadRoute()
        }
    }

    @ViewBuilder
    private var routeStatus: some View {
        switch routeState {
        case .loading:
            ProgressView("코스 좌표를 읽는 중입니다...")
                .frame(maxWidth: .infinity, alignment: .leading)
                .runCard()

        case .loaded(let pointCount):
            Text("코스 좌표 \(pointCount)개를 읽었습니다.")
                .font(.subheadline)
                .foregroundStyle(RunTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .runCard()

        case .empty:
            Text("이 workout에는 표시할 코스 좌표가 없습니다.")
                .font(.subheadline)
                .foregroundStyle(RunTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .runCard()

        case .failed(let message):
            Text("코스 읽기 실패: \(message)")
                .font(.subheadline)
                .foregroundStyle(RunTheme.errorText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .leading)
                .runCard()
        }
    }

    @ViewBuilder
    private var routeMap: some View {
        Map(position: $mapPosition) {
            if let route {
                MapPolyline(coordinates: route.coordinates)
                    .stroke(RunTheme.routeAccent, lineWidth: 4)

                if let first = route.coordinates.first {
                    Marker("Start", coordinate: first)
                }

                if let last = route.coordinates.last {
                    Marker("Finish", coordinate: last)
                }
            }
        }
        .mapStyle(selectedMapTheme.mapStyle)
        .runMapTheme(selectedMapTheme)
        .frame(maxWidth: .infinity, minHeight: 320)
        .clipShape(RoundedRectangle(cornerRadius: RunTheme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: RunTheme.cardRadius)
                .stroke(RunTheme.divider, lineWidth: 1)
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
                    mapPosition = .region(RunRouteMapRegion.region(for: route.coordinates))
                }

            case .failure(let error):
                routeState = .failed(error.localizedDescription)
            }
        }
    }
}

private enum RouteState: Equatable {
    case loading
    case loaded(Int)
    case empty
    case failed(String)
}
