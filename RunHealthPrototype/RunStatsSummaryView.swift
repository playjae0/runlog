import SwiftUI

struct RunStatsSummaryView: View {
    let stats: RunStats
    let workouts: [RunWorkout]

    private let calendar = Calendar.current
    private let now = Date()

    private let supportColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: RunTheme.contentSpacing) {
            RunSectionTitle(
                title: "내 러닝 기록",
                caption: "누적 거리와 최근 흐름"
            )

            VStack(spacing: RunTheme.contentSpacing) {
                primaryDistanceSummary
                supportStatsSummary
            }
        }
    }

    private var primaryDistanceSummary: some View {
        NavigationLink {
            RunWorkoutLogView(
                title: RunStatsPeriod.allTime.title,
                workouts: filteredWorkouts(for: .allTime)
            )
        } label: {
            RunHeroCard(
                title: "누적 거리",
                systemImage: "figure.run",
                value: WorkoutFormatter.kilometers(stats.totalDistanceKilometers),
                subtitle: "지금까지 쌓인 전체 러닝 거리"
            ) {
                HStack(spacing: 12) {
                    compactMetric(
                        title: "이번 달",
                        value: WorkoutFormatter.kilometers(stats.distanceThisMonthKilometers)
                    )

                    compactMetric(
                        title: "올해",
                        value: WorkoutFormatter.kilometers(stats.distanceThisYearKilometers)
                    )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var supportStatsSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("러닝 흐름")
                .font(RunTheme.caption)
                .foregroundStyle(RunTheme.textTertiary)

            LazyVGrid(columns: supportColumns, spacing: 10) {
                logLink(
                    period: .allTime,
                    title: "총 러닝",
                    value: "\(stats.totalRuns)회",
                    systemImage: "number.circle"
                )
                logLink(
                    period: .currentMonth,
                    title: "이번 달",
                    value: "\(stats.runsThisMonth)회",
                    systemImage: "calendar"
                )
                logLink(
                    period: .currentYear,
                    title: "올해",
                    value: "\(stats.runsThisYear)회",
                    systemImage: "sparkles"
                )
                logLink(
                    period: .lastDays(7),
                    title: "최근 7일",
                    value: WorkoutFormatter.kilometers(stats.distanceLast7DaysKilometers),
                    systemImage: "clock.badge.checkmark"
                )
                logLink(
                    period: .lastDays(30),
                    title: "최근 30일",
                    value: WorkoutFormatter.kilometers(stats.distanceLast30DaysKilometers),
                    systemImage: "calendar.badge.clock"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RunTheme.caption)
                .foregroundStyle(RunTheme.textSecondary)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(RunTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RunTheme.subtleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func logLink(period: RunStatsPeriod, title: String, value: String, systemImage: String) -> some View {
        NavigationLink {
            RunWorkoutLogView(
                title: period.title,
                workouts: filteredWorkouts(for: period)
            )
        } label: {
            RunMetricCard(title: title, value: value, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private func filteredWorkouts(for period: RunStatsPeriod) -> [RunWorkout] {
        let calculator = RunStatsCalculator(
            workouts: workouts,
            calendar: calendar,
            now: now
        )

        return workouts.filter { workout in
            calculator.matches(period, workout: workout)
        }
    }
}

#Preview {
    RunStatsSummaryView(
        stats: RunStats(
            totalRuns: 42,
            totalDistanceKilometers: 314.25,
            runsThisMonth: 6,
            distanceThisMonthKilometers: 48.3,
            runsThisYear: 29,
            distanceThisYearKilometers: 208.7,
            distanceLast7DaysKilometers: 12.4,
            distanceLast30DaysKilometers: 57.8
        ),
        workouts: []
    )
}
