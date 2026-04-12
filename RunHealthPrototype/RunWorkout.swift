import Foundation

struct RunWorkout: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distanceMeters: Double?

    init(summary: RunningWorkoutSummary) {
        id = summary.id
        startDate = summary.startDate
        endDate = summary.endDate
        duration = summary.duration
        distanceMeters = summary.distanceMeters
    }
}
