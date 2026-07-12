import Foundation

struct RunWorkout: Identifiable, Codable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distanceMeters: Double?
    let averageHeartRate: Double?

    init(summary: RunningWorkoutSummary) {
        id = summary.id
        startDate = summary.startDate
        endDate = summary.endDate
        duration = summary.duration
        distanceMeters = summary.distanceMeters
        averageHeartRate = summary.averageHeartRate
    }
}
