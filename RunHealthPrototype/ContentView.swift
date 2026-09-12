import SwiftUI

struct ContentView: View {
    @State private var isRequestingAuthorization = false
    @State private var isLoadingWorkouts = false
    @State private var isShowingSettings = false
    @State private var hasLoadedInitialData = false
    @State private var viewState: RunListState = .permissionNotRequested
    @State private var recentWorkouts: [RunWorkout] = []
    @State private var runStats = RunStats.empty
    @State private var lastCacheRefresh: Date?

    private let healthKitService = HealthKitService()
    private let cacheStore = RunWorkoutCacheStore()

    var body: some View {
        NavigationStack {
            TabView {
                summaryPage
                    .tabItem {
                        Label("요약", systemImage: "chart.line.uptrend.xyaxis")
                    }

                MonthlyRunArchiveView(workouts: recentWorkouts)
                    .tabItem {
                        Label("월별", systemImage: "calendar")
                    }

                RunWorkoutLogView(
                    title: "상세 이력",
                    workouts: recentWorkouts
                )
                .tabItem {
                    Label("이력", systemImage: "list.bullet")
                }
            }
            .tint(RunTheme.accent)
            .navigationTitle(RunTheme.appName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                NavigationStack {
                    RunSettingsView(
                        viewState: viewState,
                        isRequestingAuthorization: isRequestingAuthorization,
                        isLoadingWorkouts: isLoadingWorkouts,
                        lastCacheRefresh: lastCacheRefresh,
                        requestHealthPermission: requestHealthPermission,
                        loadRunningWorkouts: loadRunningWorkouts
                    )
                }
                .presentationDetents([.medium])
            }
            .task {
                guard !hasLoadedInitialData else {
                    return
                }

                hasLoadedInitialData = true
                loadCachedWorkouts()

                if !recentWorkouts.isEmpty {
                    refreshRunningWorkouts(isAutomatic: true)
                }
            }
        }
        .background(RunTheme.screenBackground)
    }

    private var summaryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RunTheme.sectionSpacing) {
                header
                statusView

                if viewState == .loading && recentWorkouts.isEmpty {
                    ProgressView("러닝 workout을 조회하는 중입니다...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    LastRunSummaryView(workout: recentWorkouts.first)
                    RunStatsSummaryView(stats: runStats, workouts: recentWorkouts)
                }
            }
            .padding(RunTheme.pagePadding)
        }
        .background(RunTheme.screenBackground)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(RunTheme.accentSoft)
                    .frame(width: 52, height: 52)

                Image(systemName: "figure.run")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(RunTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(RunTheme.appName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(RunTheme.textPrimary)

                Text(RunTheme.tagline)
                    .font(RunTheme.body)
                    .foregroundStyle(RunTheme.textSecondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusView: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: viewState.isError ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(viewState.isError ? RunTheme.errorText : RunTheme.accent)

            Text(viewState.message)
                .font(RunTheme.caption)
                .foregroundStyle(viewState.isError ? RunTheme.errorText : RunTheme.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
            .background(viewState.isError ? RunTheme.errorBackground : RunTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func requestHealthPermission() {
        isRequestingAuthorization = true
        viewState = .loading

        Task {
            let result = await healthKitService.requestRunningWorkoutReadPermission()

            await MainActor.run {
                isRequestingAuthorization = false

                switch result {
                case .unavailable:
                    viewState = .error("이 기기에서는 Health 데이터를 사용할 수 없습니다.")
                case .requestCompleted:
                    viewState = .permissionRequested
                    refreshRunningWorkouts(isAutomatic: false)
                case .failed(let message):
                    viewState = .error("Health 권한 요청 실패: \(message)")
                }
            }
        }
    }

    private func loadRunningWorkouts() {
        refreshRunningWorkouts(isAutomatic: false)
    }

    private func loadCachedWorkouts() {
        let cache = cacheStore.load()

        guard !cache.workouts.isEmpty else {
            return
        }

        apply(workouts: cache.workouts)
        lastCacheRefresh = cache.lastRefreshedAt
        viewState = .cached(cache.workouts.count, cache.lastRefreshedAt)
    }

    private func refreshRunningWorkouts(isAutomatic: Bool) {
        isLoadingWorkouts = true

        if recentWorkouts.isEmpty {
            viewState = .loading
        } else {
            viewState = .refreshing(recentWorkouts.count)
        }

        Task {
            let result = await healthKitService.fetchRecentRunningWorkouts(days: 365)

            await MainActor.run {
                isLoadingWorkouts = false

                switch result {
                case .success(let workouts):
                    let mappedWorkouts = workouts.map(RunWorkout.init)
                    let refreshedAt = Date()
                    apply(workouts: mappedWorkouts)
                    lastCacheRefresh = refreshedAt

                    do {
                        try cacheStore.save(
                            workouts: mappedWorkouts,
                            refreshedAt: refreshedAt
                        )
                    } catch {
                        viewState = .error("러닝 기록 캐시 저장 실패: \(error.localizedDescription)")
                        return
                    }

                    if workouts.isEmpty {
                        viewState = .empty
                    } else {
                        viewState = .loaded(workouts.count)
                    }
                case .failure(let error):
                    if isAutomatic && !recentWorkouts.isEmpty {
                        viewState = .cached(recentWorkouts.count, lastCacheRefresh)
                    } else {
                        viewState = .error("러닝 workout 조회 실패: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func apply(workouts: [RunWorkout]) {
        recentWorkouts = workouts.sorted { $0.startDate > $1.startDate }
        runStats = RunStats.calculate(from: recentWorkouts)
    }
}

private struct RunSettingsView: View {
    @AppStorage(MapTheme.storageKey) private var selectedMapThemeRawValue = MapTheme.system.rawValue
    let viewState: RunListState
    let isRequestingAuthorization: Bool
    let isLoadingWorkouts: Bool
    let lastCacheRefresh: Date?
    let requestHealthPermission: () -> Void
    let loadRunningWorkouts: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var selectedMapTheme: MapTheme {
        get { MapTheme(rawValue: selectedMapThemeRawValue) ?? .system }
        nonmutating set { selectedMapThemeRawValue = newValue.rawValue }
    }

    var body: some View {
        List {
            Section("Health") {
                Text(viewState.message)
                    .font(.subheadline)
                    .foregroundStyle(viewState.isError ? RunTheme.errorText : RunTheme.secondaryText)

                if let lastCacheRefresh {
                    LabeledContent(
                        "마지막 갱신",
                        value: lastCacheRefresh.formatted(date: .abbreviated, time: .shortened)
                    )
                    .font(.footnote)
                    .foregroundStyle(RunTheme.tertiaryText)
                }

                Button {
                    requestHealthPermission()
                } label: {
                    Label(
                        isRequestingAuthorization ? "권한 요청 중..." : "Health 권한 요청",
                        systemImage: "heart.text.square"
                    )
                }
                .disabled(isRequestingAuthorization)

                Button {
                    loadRunningWorkouts()
                    dismiss()
                } label: {
                    Label(
                        isLoadingWorkouts ? "불러오는 중..." : "러닝 기록 불러오기",
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(isLoadingWorkouts)
            }

            Section("지도") {
                Picker(
                    "지도 테마",
                    selection: Binding(
                        get: { selectedMapTheme },
                        set: { selectedMapTheme = $0 }
                    )
                ) {
                    ForEach(MapTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("안내") {
                Text("앱은 저장된 최근 1년 러닝 기록을 먼저 보여준 뒤, HealthKit에서 새 기록을 다시 불러와 갱신합니다.")
                    .font(.footnote)
                    .foregroundStyle(RunTheme.tertiaryText)
            }
        }
        .navigationTitle("설정")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("닫기") {
                    dismiss()
                }
            }
        }
    }
}

private enum RunListState: Equatable {
    case permissionNotRequested
    case permissionRequested
    case loading
    case refreshing(Int)
    case cached(Int, Date?)
    case loaded(Int)
    case empty
    case error(String)

    var message: String {
        switch self {
        case .permissionNotRequested:
            return "설정에서 Health 권한을 요청하고 러닝 기록을 불러오세요."
        case .permissionRequested:
            return "Health 권한 요청이 완료되었습니다. 설정에서 기록을 불러오세요."
        case .loading:
            return "처리 중입니다."
        case .refreshing(let count):
            return "저장된 러닝 \(count)개를 표시하면서 새 기록을 확인하는 중입니다."
        case .cached(let count, let date):
            if let date {
                return "저장된 러닝 \(count)개를 표시 중입니다. 마지막 갱신: \(date.formatted(date: .abbreviated, time: .shortened))"
            }

            return "저장된 러닝 \(count)개를 표시 중입니다."
        case .loaded(let count):
            return "최근 1년 running workout \(count)개를 읽었습니다."
        case .empty:
            return "최근 1년 running workout이 없거나 Health 읽기 권한이 허용되지 않았습니다. Health 앱과 권한 설정을 확인해 주세요."
        case .error(let message):
            return message
        }
    }

    var isError: Bool {
        if case .error = self {
            return true
        }

        return false
    }
}

#Preview {
    ContentView()
}
