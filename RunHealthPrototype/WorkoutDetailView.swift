import SwiftUI

struct WorkoutDetailView: View {
    let workout: RunWorkout
    @State private var isShowingFullscreenReplay = false

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
                detailRow(
                    title: "평균 심박수",
                    value: WorkoutFormatter.heartRate(workout.averageHeartRate)
                )
            }

            Section("코스") {
                NavigationLink {
                    WorkoutRouteMapView(workout: workout)
                } label: {
                    RunActionRowCard(
                        title: "코스 지도 보기",
                        subtitle: "러닝 route를 지도에서 확인합니다.",
                        systemImage: "map"
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                NavigationLink {
                    WorkoutReplayView(workout: workout)
                } label: {
                    RunActionRowCard(
                        title: "경로 리플레이 보기",
                        subtitle: "이동 경로를 순서대로 재생합니다.",
                        systemImage: "play.circle"
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Button {
                    isShowingFullscreenReplay = true
                } label: {
                    RunActionRowCard(
                        title: "전체 화면 보기",
                        subtitle: "캡처용 최소 UI로 리플레이를 재생합니다.",
                        systemImage: "rectangle.inset.filled.and.person.filled"
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(RunTheme.screenBackground)
        .navigationTitle("러닝 상세")
        .tint(RunTheme.accent)
        .fullScreenCover(isPresented: $isShowingFullscreenReplay) {
            FullscreenReplayView(
                workout: workout,
                initialCameraMode: .cinematic
            )
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(RunTheme.caption)
                .foregroundStyle(RunTheme.textSecondary)
            Spacer()
            Text(value)
                .font(RunTheme.body)
                .foregroundStyle(RunTheme.textPrimary)
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
                distanceMeters: 10_000,
                averageHeartRate: 148
            )
        )
    )
}
