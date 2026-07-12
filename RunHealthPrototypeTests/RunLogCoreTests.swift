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

    func testRouteNormalizationMergesAndSortsGroups() {
        let start = Date(timeIntervalSince1970: 1_000)
        let later = point(latitude: 37.2, longitude: 127.2, timestamp: start.addingTimeInterval(20))
        let first = point(latitude: 37, longitude: 127, timestamp: start)
        let middle = point(latitude: 37.1, longitude: 127.1, timestamp: start.addingTimeInterval(10))

        let normalized = normalizeRunRoutePoints([[later], [first, middle]])

        XCTAssertEqual(normalized.map(\.timestamp), [first.timestamp, middle.timestamp, later.timestamp])
    }

    func testRouteNormalizationRemovesOnlyExactCoordinateTimestampDuplicates() {
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let original = point(latitude: 37, longitude: 127, timestamp: timestamp)
        let duplicate = point(latitude: 37, longitude: 127, timestamp: timestamp)
        let sameTimeDifferentCoordinate = point(latitude: 38, longitude: 128, timestamp: timestamp)
        let sameCoordinateDifferentTime = point(
            latitude: 37,
            longitude: 127,
            timestamp: timestamp.addingTimeInterval(1)
        )

        let normalized = normalizeRunRoutePoints([
            [original, duplicate, sameTimeDifferentCoordinate, sameCoordinateDifferentTime]
        ])

        XCTAssertEqual(normalized.count, 3)
        XCTAssertTrue(normalized.contains { $0.latitude == 38 && $0.longitude == 128 })
        XCTAssertTrue(normalized.contains { $0.timestamp == sameCoordinateDifferentTime.timestamp })
    }

    func testRouteNormalizationFiltersInvalidCoordinates() {
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let valid = point(latitude: 37, longitude: 127, timestamp: timestamp)
        let invalidLatitude = point(latitude: 91, longitude: 127, timestamp: timestamp)
        let invalidLongitude = point(latitude: 37, longitude: 181, timestamp: timestamp)

        let normalized = normalizeRunRoutePoints([[invalidLatitude, valid, invalidLongitude]])

        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized.first?.latitude, valid.latitude)
    }

    func testRouteNormalizationHandlesEmptyAndSinglePointInputs() {
        XCTAssertTrue(normalizeRunRoutePoints([]).isEmpty)

        let single = point(latitude: 37, longitude: 127, timestamp: .now)
        let normalized = normalizeRunRoutePoints([[single]])

        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized.first?.timestamp, single.timestamp)
    }

    func testRouteNormalizationPreservesDistanceAndElapsedTimeForOrderedRoute() {
        let start = Date(timeIntervalSince1970: 1_000)
        let points = [
            point(latitude: 37, longitude: 127, timestamp: start),
            point(latitude: 37.001, longitude: 127, timestamp: start.addingTimeInterval(30)),
            point(latitude: 37.002, longitude: 127, timestamp: start.addingTimeInterval(60))
        ]

        let normalized = normalizeRunRoutePoints([[points[2]], [points[0], points[1]]])
        let originalDistance = makeCumulativeDistances(from: points).last
        let normalizedDistance = makeCumulativeDistances(from: normalized).last

        XCTAssertEqual(normalizedDistance ?? 0, originalDistance ?? 0, accuracy: 0.001)
        XCTAssertEqual(makeReplayElapsedTimes(from: normalized).last, 60)
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
