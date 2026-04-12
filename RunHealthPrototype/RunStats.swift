import Foundation

struct RunStats {
    let totalRuns: Int
    let totalDistanceKilometers: Double
    let runsThisMonth: Int

    static let empty = RunStats(
        totalRuns: 0,
        totalDistanceKilometers: 0,
        runsThisMonth: 0
    )

    static func calculate(
        from workouts: [RunWorkout],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> RunStats {
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let totalDistanceMeters = workouts.reduce(0) { partialResult, workout in
            partialResult + (workout.distanceMeters ?? 0)
        }

        let runsThisMonth = workouts.filter { workout in
            guard let monthInterval else {
                return false
            }

            return monthInterval.contains(workout.startDate)
        }.count

        return RunStats(
            totalRuns: workouts.count,
            totalDistanceKilometers: totalDistanceMeters / 1_000,
            runsThisMonth: runsThisMonth
        )
    }
}
