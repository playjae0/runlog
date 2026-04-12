import SwiftUI

struct ContentView: View {
    @State private var isRequestingAuthorization = false
    @State private var isLoadingWorkouts = false
    @State private var viewState: RunListState = .permissionNotRequested
    @State private var recentWorkouts: [RunWorkout] = []
    @State private var runStats = RunStats.empty

    private let healthKitService = HealthKitService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header

                Button {
                    requestHealthPermission()
                } label: {
                    Text(isRequestingAuthorization ? "Requesting..." : "Health 권한 요청")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequestingAuthorization)

                Button {
                    loadRunningWorkouts()
                } label: {
                    Text(isLoadingWorkouts ? "Loading..." : "러닝 workout 조회")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingWorkouts)

                content
            }
            .padding()
            .navigationTitle("RunHealthPrototype")
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Step 6: Workout detail")
                .font(.headline)

            Text(viewState.message)
                .font(.subheadline)
                .foregroundStyle(viewState.isError ? Color.red : Color.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewState {
        case .permissionNotRequested, .permissionRequested, .error:
            Spacer()

        case .loading:
            Spacer()
            ProgressView("러닝 workout을 조회하는 중입니다...")
            Spacer()

        case .empty:
            statsSummary
            Spacer()

        case .loaded(_):
            statsSummary

            List(recentWorkouts) { workout in
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(WorkoutFormatter.date(workout.startDate))
                            .font(.headline)

                        HStack {
                            Label(WorkoutFormatter.distance(workout.distanceMeters), systemImage: "figure.run")
                            Spacer()
                            Label(WorkoutFormatter.duration(workout.duration), systemImage: "clock")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
    }

    private var statsSummary: some View {
        HStack(spacing: 12) {
            statItem(title: "총 러닝", value: "\(runStats.totalRuns)")
            statItem(
                title: "총 거리",
                value: WorkoutFormatter.kilometers(runStats.totalDistanceKilometers)
            )
            statItem(title: "이번 달", value: "\(runStats.runsThisMonth)")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
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
                case .failed(let message):
                    viewState = .error("Health 권한 요청 실패: \(message)")
                }
            }
        }
    }

    private func loadRunningWorkouts() {
        isLoadingWorkouts = true
        viewState = .loading
        recentWorkouts = []
        runStats = .empty

        Task {
            let result = await healthKitService.fetchRecentRunningWorkouts()

            await MainActor.run {
                isLoadingWorkouts = false

                switch result {
                case .success(let workouts):
                    recentWorkouts = workouts.map(RunWorkout.init)
                    runStats = RunStats.calculate(from: recentWorkouts)

                    if workouts.isEmpty {
                        viewState = .empty
                    } else {
                        viewState = .loaded(workouts.count)
                    }
                case .failure(let error):
                    viewState = .error("러닝 workout 조회 실패: \(error.localizedDescription)")
                }
            }
        }
    }
}

private enum RunListState {
    case permissionNotRequested
    case permissionRequested
    case loading
    case loaded(Int)
    case empty
    case error(String)

    var message: String {
        switch self {
        case .permissionNotRequested:
            return "Health 권한을 요청한 뒤 러닝 목록을 조회하세요."
        case .permissionRequested:
            return "Health 권한 요청이 완료되었습니다. 러닝 workout 조회를 눌러 확인하세요."
        case .loading:
            return "처리 중입니다."
        case .loaded(let count):
            return "running workout \(count)개를 읽었습니다."
        case .empty:
            return "조회는 성공했지만 running workout 데이터가 없습니다."
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
