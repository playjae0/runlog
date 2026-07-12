import MapKit
import SwiftUI

struct MonthlyRunArchiveView: View {
    @AppStorage(MapTheme.storageKey) private var selectedMapThemeRawValue = MapTheme.system.rawValue
    let workouts: [RunWorkout]

    @State private var selectedMonth: MonthlyRunArchiveMonth
    @State private var routes: [RunRoute] = []
    @State private var routeState: MonthlyRouteLoadState = .idle
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var mapProvider: MapProvider = .apple

    private let healthKitService = HealthKitService()
    private let calendar = Calendar.current

    private var selectedMapTheme: MapTheme {
        MapTheme(rawValue: selectedMapThemeRawValue) ?? .system
    }

    init(workouts: [RunWorkout]) {
        self.workouts = workouts

        let initialMonth = MonthlyRunArchiveMonth
            .recentMonths(calendar: .current)
            .first ?? MonthlyRunArchiveMonth(
                startDate: Date(),
                endDate: Date()
            )
        _selectedMonth = State(initialValue: initialMonth)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RunTheme.sectionSpacing) {
                monthPicker
                summarySection
                routeMapSection
                workoutListSection
            }
            .padding(RunTheme.pagePadding)
        }
        .background(RunTheme.screenBackground)
        .navigationTitle("월별 러닝")
        .animation(RunTheme.smoothAnimation, value: selectedMonth)
        .animation(RunTheme.smoothAnimation, value: routeState)
        .task(id: routeTaskID) {
            await loadRoutes()
        }
    }

    private var monthOptions: [MonthlyRunArchiveMonth] {
        MonthlyRunArchiveMonth.recentMonths(calendar: calendar)
    }

    private var monthlyWorkouts: [RunWorkout] {
        workouts
            .filter { selectedMonth.contains($0.startDate) }
            .sorted { $0.startDate > $1.startDate }
    }

    private var monthlySummary: MonthlyRunArchiveSummary {
        MonthlyRunArchiveSummary.calculate(from: monthlyWorkouts)
    }

    private var routeTaskID: String {
        let workoutIDs = monthlyWorkouts.map(\.id.uuidString).joined(separator: "-")
        return "\(selectedMonth.startDate.timeIntervalSince1970)-\(workoutIDs)"
    }

    private var monthPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            RunSectionTitle(
                title: "월별 아카이브",
                caption: "선택한 월의 모든 러닝 route를 한 번에 봅니다"
            )

            HStack(spacing: 12) {
                Label("월 선택", systemImage: "calendar")
                    .font(RunTheme.caption)
                    .foregroundStyle(RunTheme.textSecondary)

                Spacer()

                Picker("월", selection: $selectedMonth) {
                    ForEach(monthOptions) { month in
                        Text(month.title(calendar: calendar))
                            .tag(month)
                    }
                }
                .pickerStyle(.menu)
                .tint(RunTheme.accent)
            }
            .runCard(padding: 16, shadowOpacity: 0.05)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedMonth.title(calendar: calendar))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(RunTheme.primaryText)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 12
            ) {
                summaryCard(title: "러닝 횟수", value: "\(monthlySummary.totalRuns)회", systemImage: "number.circle")
                summaryCard(
                    title: "누적 거리",
                    value: WorkoutFormatter.distance(monthlySummary.totalDistanceMeters),
                    systemImage: "figure.run"
                )
                summaryCard(title: "운동 시간", value: WorkoutFormatter.duration(monthlySummary.totalDuration), systemImage: "clock")
                summaryCard(title: "평균 페이스", value: monthlySummary.averagePace, systemImage: "speedometer")
            }
        }
    }

    private func summaryCard(title: String, value: String, systemImage: String) -> some View {
        RunMetricCard(title: title, value: value, systemImage: systemImage)
    }

    private var routeMapSection: some View {
        RunHeroCard(
            title: "누적 경로 지도",
            systemImage: "map",
            value: selectedMonth.title(calendar: calendar),
            subtitle: "선택한 월의 러닝 route를 한 번에 확인합니다."
        ) {
            HStack(alignment: .center, spacing: 12) {
                routeStatusBadge
                Spacer()
                MapProviderPicker(selection: $mapProvider)
                    .frame(maxWidth: 220)
            }

            routeMapContent
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: RunTheme.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: RunTheme.cardRadius, style: .continuous)
                        .stroke(RunTheme.borderSubtle, lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private var routeMapContent: some View {
        switch routeState {
        case .idle, .loading:
            ProgressView("월별 경로를 불러오는 중입니다...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RunTheme.subtleBackground)

        case .empty:
            Text("이 월에는 러닝 기록이 없습니다.")
                .font(.subheadline)
                .foregroundStyle(RunTheme.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RunTheme.subtleBackground)

        case .failed(let message):
            Text("월별 경로 불러오기 실패: \(message)")
                .font(.subheadline)
                .foregroundStyle(RunTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
                .background(RunTheme.subtleBackground)

        case .loaded:
            if routes.isEmpty {
                Text("표시할 route가 있는 러닝이 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(RunTheme.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RunTheme.subtleBackground)
            } else {
                Group {
                    switch mapProvider {
                    case .apple:
                        Map(position: $mapPosition) {
                            ForEach(routes) { route in
                                MapPolyline(coordinates: route.coordinates)
                                    .stroke(RunTheme.routeAccent, lineWidth: 4)
                            }
                        }
                        .mapStyle(selectedMapTheme.mapStyle)
                        .runMapTheme(selectedMapTheme)

                    case .google:
                        if GoogleMapsBootstrap.isConfigured {
                            GoogleMapView(
                                routes: routes.map(\.coordinates),
                                currentCoordinate: nil,
                                lineColor: UIColor(RunTheme.routeAccent),
                                mapTheme: selectedMapTheme,
                                showsStartMarker: false,
                                showsEndMarker: false
                            )
                        } else {
                            Text("Google Maps API 키를 설정하면 월별 누적 경로를 비교할 수 있습니다.")
                                .font(.subheadline)
                                .foregroundStyle(RunTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(RunTheme.subtleBackground)
                        }
                    }
                }
            }
        }
    }

    private var routeStatusText: String {
        switch routeState {
        case .idle:
            return "대기 중"
        case .loading:
            return "로딩 중"
        case .empty:
            return "0 / 0 표시"
        case .failed:
            return "조회 실패"
        case .loaded(let displayedRoutes, let totalWorkouts, let missingRoutes, let failedRoutes):
            var text = "\(displayedRoutes) / \(totalWorkouts) 표시"

            if missingRoutes > 0 {
                text += ", route 없음 \(missingRoutes)"
            }

            if failedRoutes > 0 {
                text += ", 실패 \(failedRoutes)"
            }

            return text
        }
    }

    private var routeStatusBadge: some View {
        switch routeState {
        case .idle:
            RunBadge(text: "대기 중", systemImage: "pause.circle", tone: .neutral)
        case .loading:
            RunBadge(text: "로딩 중", systemImage: "arrow.triangle.2.circlepath", tone: .accent)
        case .empty:
            RunBadge(text: "0 / 0 표시", systemImage: "map", tone: .neutral)
        case .failed:
            RunBadge(text: "조회 실패", systemImage: "exclamationmark.triangle", tone: .error)
        case .loaded:
            RunBadge(text: routeStatusText, systemImage: "map.fill", tone: .accent)
        }
    }

    private var workoutListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("개별 러닝")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(RunTheme.primaryText)

            if monthlyWorkouts.isEmpty {
                Text("선택한 월에 해당하는 러닝 기록이 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(RunTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .runCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(monthlyWorkouts) { workout in
                        NavigationLink {
                            WorkoutDetailView(workout: workout)
                        } label: {
                            monthlyWorkoutRow(workout)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func monthlyWorkoutRow(_ workout: RunWorkout) -> some View {
        RunActionRowCard(
            title: WorkoutFormatter.date(workout.startDate),
            subtitle: "\(WorkoutFormatter.distance(workout.distanceMeters))  •  \(WorkoutFormatter.duration(workout.duration))",
            systemImage: "figure.run"
        )
    }

    private func loadRoutes() async {
        guard !monthlyWorkouts.isEmpty else {
            await MainActor.run {
                routes = []
                routeState = .empty
            }
            return
        }

        await MainActor.run {
            routes = []
            routeState = .loading
        }

        let result = await healthKitService.fetchRoutes(
            for: monthlyWorkouts.map(\.id)
        )

        await MainActor.run {
            withAnimation(RunTheme.smoothAnimation) {
                routes = result.routes

                let coordinates = result.routes.flatMap(\.coordinates)
                if !coordinates.isEmpty {
                    mapPosition = .region(RunRouteMapRegion.region(for: coordinates))
                }

                if result.routes.isEmpty,
                   result.failedWorkoutIDs.count == monthlyWorkouts.count {
                    routeState = .failed("모든 workout route 조회에 실패했습니다.")
                } else {
                    routeState = .loaded(
                        displayedRoutes: result.routes.count,
                        totalWorkouts: monthlyWorkouts.count,
                        missingRoutes: result.missingRouteWorkoutIDs.count,
                        failedRoutes: result.failedWorkoutIDs.count
                    )
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MonthlyRunArchiveView(
            workouts: [
                RunWorkout(
                    summary: RunningWorkoutSummary(
                        id: UUID(),
                        startDate: .now.addingTimeInterval(-3_600),
                        endDate: .now,
                        duration: 3_600,
                        distanceMeters: 10_000,
                        averageHeartRate: 148
                    )
                )
            ]
        )
    }
}
