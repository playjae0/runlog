import SwiftUI

struct RunWorkoutLogView: View {
    let title: String
    let workouts: [RunWorkout]
    @State private var sortOrder: RunWorkoutSortOrder = .newest

    var body: some View {
        List {
            if !workouts.isEmpty {
                Picker("정렬", selection: $sortOrder) {
                    ForEach(RunWorkoutSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .listRowBackground(Color.clear)
            }

            if workouts.isEmpty {
                Text("이 범위에 해당하는 러닝 기록이 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(RunTheme.secondaryText)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(sortedWorkouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        workoutRow(workout)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(
                            top: 6,
                            leading: RunTheme.pagePadding,
                            bottom: 6,
                            trailing: RunTheme.pagePadding
                        )
                    )
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RunTheme.screenBackground)
        .navigationTitle(title)
    }

    private var sortedWorkouts: [RunWorkout] {
        workouts.sorted(by: sortOrder.areInIncreasingOrder)
    }

    private func workoutRow(_ workout: RunWorkout) -> some View {
        VStack(alignment: .leading, spacing: RunTheme.cardInnerSpacing) {
            Text(WorkoutFormatter.date(workout.startDate))
                .font(RunTheme.title)
                .foregroundStyle(RunTheme.textPrimary)

            HStack(spacing: 12) {
                Label(WorkoutFormatter.distance(workout.distanceMeters), systemImage: "figure.run")
                Spacer()
                Label(WorkoutFormatter.duration(workout.duration), systemImage: "clock")
                Spacer()
                Label(WorkoutFormatter.heartRate(workout.averageHeartRate), systemImage: "heart")
            }
            .font(RunTheme.caption)
            .foregroundStyle(RunTheme.textSecondary)
        }
        .runCard(padding: 16, shadowOpacity: 0.05)
    }
}

private enum RunWorkoutSortOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case distance
    case pace

    var id: Self { self }

    var title: String {
        switch self {
        case .newest: return "최신순"
        case .oldest: return "오래된순"
        case .distance: return "거리순"
        case .pace: return "페이스순"
        }
    }

    func areInIncreasingOrder(_ lhs: RunWorkout, _ rhs: RunWorkout) -> Bool {
        switch self {
        case .newest:
            return lhs.startDate > rhs.startDate
        case .oldest:
            return lhs.startDate < rhs.startDate
        case .distance:
            return (lhs.distanceMeters ?? -1) > (rhs.distanceMeters ?? -1)
        case .pace:
            return paceValue(for: lhs) < paceValue(for: rhs)
        }
    }

    private func paceValue(for workout: RunWorkout) -> Double {
        guard let distance = workout.distanceMeters, distance > 0 else {
            return .greatestFiniteMagnitude
        }

        return workout.duration / (distance / 1_000)
    }
}
