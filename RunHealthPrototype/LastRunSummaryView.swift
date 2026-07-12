import MapKit
import SwiftUI

struct LastRunSummaryView: View {
    let workout: RunWorkout?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RunSectionTitle(
                title: "마지막 러닝",
                caption: "최근 기록과 route를 빠르게 확인하세요"
            )

            if let workout {
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    RunHeroCard(
                        title: WorkoutFormatter.date(workout.startDate),
                        systemImage: "location.fill",
                        value: WorkoutFormatter.distance(workout.distanceMeters),
                        subtitle: "시간 \(WorkoutFormatter.duration(workout.duration))  •  심박 \(WorkoutFormatter.heartRate(workout.averageHeartRate))"
                    ) {
                        LastRunRoutePreview(workout: workout)
                    }
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("아직 불러온 러닝 기록이 없습니다.")
                        .font(RunTheme.title)
                        .foregroundStyle(RunTheme.textPrimary)
                    Text("오른쪽 위 설정에서 Health 권한을 요청하고 기록을 불러오면 마지막 러닝과 경로가 여기에 표시됩니다.")
                        .font(RunTheme.body)
                        .foregroundStyle(RunTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .runCard()
            }
        }
    }
}

private struct LastRunRoutePreview: View {
    @AppStorage(MapTheme.storageKey) private var selectedMapThemeRawValue = MapTheme.system.rawValue
    let workout: RunWorkout

    @State private var route: RunRoute?
    @State private var routeState: RoutePreviewState = .loading
    @State private var mapPosition: MapCameraPosition = .automatic

    private let healthKitService = HealthKitService()

    private var selectedMapTheme: MapTheme {
        MapTheme(rawValue: selectedMapThemeRawValue) ?? .system
    }

    var body: some View {
        Group {
            switch routeState {
            case .loading:
                ProgressView("경로를 불러오는 중입니다...")
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .background(RunTheme.subtleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: RunTheme.cardRadius, style: .continuous))

            case .loaded:
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
                .frame(height: 180)
                .mapStyle(selectedMapTheme.mapStyle)
                .runMapTheme(selectedMapTheme)
                .clipShape(RoundedRectangle(cornerRadius: RunTheme.cardRadius, style: .continuous))
                .allowsHitTesting(false)

            case .empty:
                Text("이 러닝에는 표시할 경로 데이터가 없습니다.")
                    .font(.footnote)
                    .foregroundStyle(RunTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .runCard(background: RunTheme.subtleBackground, shadowOpacity: 0)

            case .failed(let message):
                Text("경로 불러오기 실패: \(message)")
                    .font(.footnote)
                    .foregroundStyle(RunTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .runCard(background: RunTheme.subtleBackground, shadowOpacity: 0)
            }
        }
        .animation(RunTheme.smoothAnimation, value: routeState)
        .task(id: workout.id) {
            await loadRoute()
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
                    routeState = .loaded
                    mapPosition = .region(RunRouteMapRegion.region(for: route.coordinates))
                }

            case .failure(let error):
                routeState = .failed(error.localizedDescription)
            }
        }
    }
}

private enum RoutePreviewState: Equatable {
    case loading
    case loaded
    case empty
    case failed(String)
}
