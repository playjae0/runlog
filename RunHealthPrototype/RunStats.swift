import Foundation

struct RunStats {
    let totalRuns: Int
    let totalDistanceKilometers: Double
    let runsThisMonth: Int
    let distanceThisMonthKilometers: Double
    let runsThisYear: Int
    let distanceThisYearKilometers: Double
    let distanceLast7DaysKilometers: Double
    let distanceLast30DaysKilometers: Double

    static let empty = RunStats(
        totalRuns: 0,
        totalDistanceKilometers: 0,
        runsThisMonth: 0,
        distanceThisMonthKilometers: 0,
        runsThisYear: 0,
        distanceThisYearKilometers: 0,
        distanceLast7DaysKilometers: 0,
        distanceLast30DaysKilometers: 0
    )

    static func calculate(
        from workouts: [RunWorkout],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> RunStats {
        let calculator = RunStatsCalculator(
            workouts: workouts,
            calendar: calendar,
            now: now
        )

        let runsThisMonth = workouts.filter { workout in
            calculator.matches(.currentMonth, workout: workout)
        }.count
        let runsThisYear = workouts.filter { workout in
            calculator.matches(.currentYear, workout: workout)
        }.count

        return RunStats(
            totalRuns: workouts.count,
            totalDistanceKilometers: calculator.distanceKilometers(in: .allTime),
            runsThisMonth: runsThisMonth,
            distanceThisMonthKilometers: calculator.distanceKilometers(in: .currentMonth),
            runsThisYear: runsThisYear,
            distanceThisYearKilometers: calculator.distanceKilometers(in: .currentYear),
            distanceLast7DaysKilometers: calculator.distanceKilometers(in: .lastDays(7)),
            distanceLast30DaysKilometers: calculator.distanceKilometers(in: .lastDays(30))
        )
    }
}

enum RunStatsPeriod {
    case allTime
    case currentMonth
    case currentYear
    case lastDays(Int)

    var title: String {
        switch self {
        case .allTime:
            return "최근 1년 러닝 로그"
        case .currentMonth:
            return "이번 달 러닝 로그"
        case .currentYear:
            return "올해 러닝 로그"
        case .lastDays(let days):
            return "최근 \(days)일 러닝 로그"
        }
    }
}

struct RunStatsCalculator {
    let workouts: [RunWorkout]
    let calendar: Calendar
    let now: Date

    func distanceKilometers(in period: RunStatsPeriod) -> Double {
        let meters = workouts.reduce(0) { partialResult, workout in
            guard matches(period, workout: workout) else {
                return partialResult
            }

            return partialResult + (workout.distanceMeters ?? 0)
        }

        return meters / 1_000
    }

    func matches(_ period: RunStatsPeriod, workout: RunWorkout) -> Bool {
        switch period {
        case .allTime:
            return true

        case .currentMonth:
            return calendar.dateInterval(of: .month, for: now)?.contains(workout.startDate) ?? false

        case .currentYear:
            return calendar.dateInterval(of: .year, for: now)?.contains(workout.startDate) ?? false

        case .lastDays(let days):
            guard let startDate = calendar.date(
                byAdding: .day,
                value: -days,
                to: now
            ) else {
                return false
            }

            return workout.startDate >= startDate && workout.startDate <= now
        }
    }
}
