import Foundation

enum WorkoutFormatter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func day(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func distance(_ meters: Double?) -> String {
        guard let meters else {
            return "거리 없음"
        }

        return String(format: "%.2f km", meters / 1_000)
    }

    static func kilometers(_ kilometers: Double) -> String {
        String(format: "%.2f km", kilometers)
    }

    static func duration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }

    static func averagePace(distanceMeters: Double?, duration: TimeInterval) -> String {
        guard let distanceMeters, distanceMeters > 0, duration > 0 else {
            return "페이스 없음"
        }

        let roundedSecondsPerKilometer = Int((duration / (distanceMeters / 1_000)).rounded())
        let paceMinutes = roundedSecondsPerKilometer / 60
        let paceSeconds = roundedSecondsPerKilometer % 60

        return String(format: "%d:%02d / km", paceMinutes, paceSeconds)
    }
}
