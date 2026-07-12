import Foundation

struct MonthlyRunArchiveMonth: Identifiable, Hashable {
    let startDate: Date
    let endDate: Date

    var id: Date {
        startDate
    }

    func contains(_ date: Date) -> Bool {
        startDate <= date && date < endDate
    }

    func title(calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: startDate)
    }

    static func recentMonths(
        count: Int = 24,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [MonthlyRunArchiveMonth] {
        guard let currentMonth = calendar.dateInterval(of: .month, for: now) else {
            return []
        }

        return (0..<count).compactMap { offset in
            guard
                let startDate = calendar.date(
                    byAdding: .month,
                    value: -offset,
                    to: currentMonth.start
                ),
                let month = calendar.dateInterval(of: .month, for: startDate)
            else {
                return nil
            }

            return MonthlyRunArchiveMonth(
                startDate: month.start,
                endDate: month.end
            )
        }
    }
}

struct MonthlyRunArchiveSummary {
    let totalRuns: Int
    let totalDistanceMeters: Double
    let totalDuration: TimeInterval

    var averagePace: String {
        WorkoutFormatter.averagePace(
            distanceMeters: totalDistanceMeters,
            duration: totalDuration
        )
    }

    static func calculate(from workouts: [RunWorkout]) -> MonthlyRunArchiveSummary {
        MonthlyRunArchiveSummary(
            totalRuns: workouts.count,
            totalDistanceMeters: workouts.reduce(0) { $0 + ($1.distanceMeters ?? 0) },
            totalDuration: workouts.reduce(0) { $0 + $1.duration }
        )
    }
}

enum MonthlyRouteLoadState: Equatable {
    case idle
    case loading
    case loaded(displayedRoutes: Int, totalWorkouts: Int, missingRoutes: Int, failedRoutes: Int)
    case empty
    case failed(String)
}
