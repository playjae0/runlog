import SwiftUI

struct RunWorkoutLogView: View {
    let title: String
    let workouts: [RunWorkout]

    var body: some View {
        List {
            if workouts.isEmpty {
                Text("이 범위에 해당하는 러닝 기록이 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(RunTheme.secondaryText)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(workouts) { workout in
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
