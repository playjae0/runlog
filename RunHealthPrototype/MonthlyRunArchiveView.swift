import MapKit
import SwiftUI

struct MonthlyRunArchiveView: View {
    @AppStorage(MapTheme.storageKey) private var selectedMapThemeRawValue = MapTheme.system.rawValue
    let workouts: [RunWorkout]

    @State private var selectedMonth: MonthlyRunArchiveMonth
    @State private var routes: [RunRoute] = []
    @State private var routeState: MonthlyRouteLoadState = .idle
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var selectedWorkoutID: UUID?

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
        .onChange(of: selectedMonth) { _, _ in
            selectedWorkoutID = nil
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
                caption: "최근 24개월의 러닝 route를 한 번에 봅니다"
            )

            HStack(spacing: 12) {
                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canMoveToOlderMonth)

                Picker("월", selection: $selectedMonth) {
                    ForEach(monthOptions) { month in
                        Text(month.title(calendar: calendar))
                            .tag(month)
                    }
                }
                .pickerStyle(.menu)
                .tint(RunTheme.accent)

                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canMoveToNewerMonth)
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
                Map(position: $mapPosition) {
                    ForEach(routes) { route in
                        MapPolyline(coordinates: route.coordinates)
                            .stroke(
                                routeColor(for: route),
                                lineWidth: selectedWorkoutID == route.workoutID ? 7 : 4
                            )
                    }
                }
                .mapStyle(selectedMapTheme.mapStyle)
                .runMapTheme(selectedMapTheme)
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
                        Button {
                            selectWorkout(workout)
                        } label: {
                            monthlyWorkoutRow(workout)
                        }
                        .buttonStyle(.plain)
                        .overlay {
                            if selectedWorkoutID == workout.id {
                                RoundedRectangle(cornerRadius: RunTheme.cardRadius, style: .continuous)
                                    .stroke(RunTheme.accent, lineWidth: 2)
                            }
                        }
                    }

                    if let selectedWorkout {
                        NavigationLink {
                            WorkoutDetailView(workout: selectedWorkout)
                        } label: {
                            Label("선택한 러닝 상세 보기", systemImage: "arrow.right.circle.fill")
                                .font(RunTheme.body)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
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

    private var selectedWorkout: RunWorkout? {
        guard let selectedWorkoutID else {
            return nil
        }

        return monthlyWorkouts.first { $0.id == selectedWorkoutID }
    }

    private var selectedMonthIndex: Int? {
        monthOptions.firstIndex(of: selectedMonth)
    }

    private var canMoveToOlderMonth: Bool {
        guard let selectedMonthIndex else {
            return false
        }

        return selectedMonthIndex < monthOptions.count - 1
    }

    private var canMoveToNewerMonth: Bool {
        guard let selectedMonthIndex else {
            return false
        }

        return selectedMonthIndex > 0
    }

    private func moveMonth(by indexOffset: Int) {
        guard let selectedMonthIndex else {
            return
        }

        let nextIndex = selectedMonthIndex + indexOffset
        guard monthOptions.indices.contains(nextIndex) else {
            return
        }

        selectedMonth = monthOptions[nextIndex]
    }

    private func selectWorkout(_ workout: RunWorkout) {
        selectedWorkoutID = workout.id

        guard let route = routes.first(where: { $0.workoutID == workout.id }),
              !route.coordinates.isEmpty else {
            return
        }

        withAnimation(RunTheme.smoothAnimation) {
            mapPosition = .region(RunRouteMapRegion.region(for: route.coordinates))
        }
    }

    private func routeColor(for route: RunRoute) -> Color {
        if let selectedWorkoutID,
           routes.contains(where: { $0.workoutID == selectedWorkoutID }),
           selectedWorkoutID != route.workoutID {
            return RunTheme.routeAccent.opacity(0.25)
        }

        let palette: [Color] = [
            RunTheme.routeAccent,
            RunTheme.accent,
            RunTheme.paceNormal,
            RunTheme.paceSlow
        ]
        let index = monthlyWorkouts.firstIndex { $0.id == route.workoutID } ?? 0
        return palette[index % palette.count]
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
