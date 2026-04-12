import SwiftUI

struct WorkoutDetailView: View {
    let workout: RunWorkout

    var body: some View {
        List {
            Section("기본 정보") {
                detailRow(
                    title: "날짜",
                    value: WorkoutFormatter.day(workout.startDate)
                )
                detailRow(
                    title: "거리",
                    value: WorkoutFormatter.distance(workout.distanceMeters)
                )
                detailRow(
                    title: "총 운동 시간",
                    value: WorkoutFormatter.duration(workout.duration)
                )
                detailRow(
                    title: "시작 시간",
                    value: WorkoutFormatter.time(workout.startDate)
                )
                detailRow(
                    title: "종료 시간",
                    value: WorkoutFormatter.time(workout.endDate)
                )
                detailRow(
                    title: "평균 페이스",
                    value: WorkoutFormatter.averagePace(
                        distanceMeters: workout.distanceMeters,
                        duration: workout.duration
                    )
                )
            }

            Section("코스") {
                NavigationLink {
                    WorkoutRouteMapView(workout: workout)
                } label: {
                    Label("코스 지도 보기", systemImage: "map")
                }
            }
        }
        .navigationTitle("Workout Detail")
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    WorkoutDetailView(
        workout: RunWorkout(
            summary: RunningWorkoutSummary(
                id: UUID(),
                startDate: .now.addingTimeInterval(-3_600),
                endDate: .now,
                duration: 3_600,
                distanceMeters: 10_000
            )
        )
    )
}
