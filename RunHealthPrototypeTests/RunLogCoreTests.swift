import XCTest
@testable import RunHealthPrototype

final class RunLogCoreTests: XCTestCase {
    func testReplayElapsedTimesUseFirstTimestamp() {
        let start = Date(timeIntervalSince1970: 1_000)
        let points = [
            point(latitude: 37, longitude: 127, timestamp: start),
            point(latitude: 37.001, longitude: 127.001, timestamp: start.addingTimeInterval(12)),
            point(latitude: 37.002, longitude: 127.002, timestamp: start.addingTimeInterval(30))
        ]

        XCTAssertEqual(makeReplayElapsedTimes(from: points), [0, 12, 30])
    }

    func testCumulativeDistanceStartsAtZeroAndIncreases() {
        let points = [
            point(latitude: 37, longitude: 127, timestamp: .distantPast),
            point(latitude: 37.001, longitude: 127, timestamp: .distantPast)
        ]

        let distances = makeCumulativeDistances(from: points)

        XCTAssertEqual(distances.first, 0)
        XCTAssertGreaterThan(distances.last ?? 0, 100)
    }

    func testDownsamplingPreservesEndpointsAndLimitShape() {
        let points = (0..<10).map { index in
            point(
                latitude: 37 + (Double(index) * 0.001),
                longitude: 127,
                timestamp: Date(timeIntervalSince1970: Double(index))
            )
        }

        let sampled = downsampleReplayPoints(from: points, maxReplayPointCount: 4)

        XCTAssertEqual(sampled.first?.latitude, points.first?.latitude)
        XCTAssertEqual(sampled.last?.latitude, points.last?.latitude)
        XCTAssertLessThan(sampled.count, points.count)
    }

    func testCurrentMonthUsesCalendarBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date(2026, 7, 12, calendar: calendar)
        let current = workout(at: date(2026, 7, 1, calendar: calendar))
        let previous = workout(at: date(2026, 6, 30, calendar: calendar))
        let calculator = RunStatsCalculator(
            workouts: [current, previous],
            calendar: calendar,
            now: now
        )

        XCTAssertTrue(calculator.matches(.currentMonth, workout: current))
        XCTAssertFalse(calculator.matches(.currentMonth, workout: previous))
    }

    func testMonthlyArchiveMonthExcludesNextMonthBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let month = MonthlyRunArchiveMonth(
            startDate: date(2026, 7, 1, calendar: calendar),
            endDate: date(2026, 8, 1, calendar: calendar)
        )

        XCTAssertTrue(month.contains(date(2026, 7, 31, hour: 23, calendar: calendar)))
        XCTAssertFalse(month.contains(date(2026, 8, 1, calendar: calendar)))
    }

    private func point(
        latitude: Double,
        longitude: Double,
        timestamp: Date
    ) -> RunRoutePoint {
        RunRoutePoint(
            latitude: latitude,
            longitude: longitude,
            timestamp: timestamp,
            altitude: nil
        )
    }

    private func workout(at startDate: Date) -> RunWorkout {
        RunWorkout(
            summary: RunningWorkoutSummary(
                id: UUID(),
                startDate: startDate,
                endDate: startDate.addingTimeInterval(1_800),
                duration: 1_800,
                distanceMeters: 5_000,
                averageHeartRate: nil
            )
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        )!
    }
}
