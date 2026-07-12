import CoreLocation
import HealthKit
import Foundation

enum HealthAuthorizationResult {
    case unavailable
    case requestCompleted
    case failed(String)
}

struct RunningWorkoutSummary: Identifiable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distanceMeters: Double?
    let averageHeartRate: Double?
}

struct RunRouteBatchResult: Sendable {
    let routes: [RunRoute]
    let missingRouteWorkoutIDs: [UUID]
    let failedWorkoutIDs: [UUID: String]
}

final class HealthKitService: @unchecked Sendable {
    private static let routeCache = RunRouteCacheStore()
    private static let routeFetchConcurrencyLimit = 4
    private static let heartRateFetchConcurrencyLimit = 4

    private let healthStore = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestRunningWorkoutReadPermission() async -> HealthAuthorizationResult {
        guard isHealthDataAvailable else {
            return .unavailable
        }

        let workoutType = HKObjectType.workoutType()
        let routeType = HKSeriesType.workoutRoute()
        var readTypes: Set<HKObjectType> = [workoutType, routeType]

        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            readTypes.insert(heartRateType)
        }

        do {
            // HealthKit does not reveal the exact allow/deny decision for read access.
            // A successful return means the authorization request flow completed.
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            return .requestCompleted
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func fetchRecentRunningWorkouts(
        days: Int = 365,
        limit: Int = HKObjectQueryNoLimit
    ) async -> Result<[RunningWorkoutSummary], Error> {
        guard isHealthDataAvailable else {
            return .failure(HealthKitServiceError.healthDataUnavailable)
        }

        do {
            let workouts = try await fetchRunningWorkouts(days: days, limit: limit)
            let heartRates = await fetchAverageHeartRates(
                for: workouts,
                concurrencyLimit: Self.heartRateFetchConcurrencyLimit
            )

            let summaries = workouts.enumerated().map { index, workout in
                RunningWorkoutSummary(
                    id: workout.uuid,
                    startDate: workout.startDate,
                    endDate: workout.endDate,
                    duration: workout.duration,
                    distanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
                    averageHeartRate: heartRates[index]
                )
            }

            return .success(summaries)
        } catch {
            return .failure(error)
        }
    }

    func fetchRoute(for workoutID: UUID) async -> Result<RunRoute, Error> {
        guard isHealthDataAvailable else {
            return .failure(HealthKitServiceError.healthDataUnavailable)
        }

        if let cachedEntry = await Self.routeCache.value(for: workoutID) {
            switch cachedEntry {
            case .route(let route):
                return .success(route)
            case .missing:
                return .failure(HealthKitServiceError.routeUnavailable)
            }
        }

        let result = await fetchUncachedRoute(for: workoutID)

        switch result {
        case .success(let route):
            await Self.routeCache.store(.route(route), for: workoutID)
        case .failure(let error):
            if let serviceError = error as? HealthKitServiceError,
               serviceError == .routeUnavailable {
                await Self.routeCache.store(.missing(cachedAt: Date()), for: workoutID)
            }
        }

        return result
    }

    func fetchRoutes(for workoutIDs: [UUID]) async -> RunRouteBatchResult {
        let collectedResults = await fetchRoutes(
            for: workoutIDs,
            concurrencyLimit: Self.routeFetchConcurrencyLimit
        )

        var routesByWorkoutID: [UUID: RunRoute] = [:]
        var missingRouteWorkoutIDs = Set<UUID>()
        var failedWorkoutIDs: [UUID: String] = [:]

        for (workoutID, result) in collectedResults {
            switch result {
            case .success(let route):
                if route.points.isEmpty {
                    missingRouteWorkoutIDs.insert(workoutID)
                } else {
                    routesByWorkoutID[workoutID] = route
                }

            case .failure(let error):
                if let serviceError = error as? HealthKitServiceError,
                   serviceError == .routeUnavailable {
                    missingRouteWorkoutIDs.insert(workoutID)
                } else {
                    failedWorkoutIDs[workoutID] = error.localizedDescription
                }
            }
        }

        let routes = workoutIDs.compactMap { routesByWorkoutID[$0] }
        let orderedMissingRouteWorkoutIDs = workoutIDs.filter { missingRouteWorkoutIDs.contains($0) }

        return RunRouteBatchResult(
            routes: routes,
            missingRouteWorkoutIDs: orderedMissingRouteWorkoutIDs,
            failedWorkoutIDs: failedWorkoutIDs
        )
    }

    private func fetchUncachedRoute(for workoutID: UUID) async -> Result<RunRoute, Error> {
        do {
            let workout = try await fetchWorkout(id: workoutID)
            let routes = try await fetchRoutes(for: workout)

            guard !routes.isEmpty else {
                return .failure(HealthKitServiceError.routeUnavailable)
            }

            var pointGroups: [[RunRoutePoint]] = []

            for route in routes {
                try Task.checkCancellation()
                let locations = try await fetchLocations(for: route)
                try Task.checkCancellation()

                pointGroups.append(
                    locations.map { location in
                        RunRoutePoint(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            timestamp: location.timestamp,
                            altitude: location.verticalAccuracy >= 0 ? location.altitude : nil
                        )
                    }
                )
            }

            let points = normalizeRunRoutePoints(pointGroups)
            guard !points.isEmpty else {
                return .failure(HealthKitServiceError.routeUnavailable)
            }

            return .success(
                RunRoute(
                    workoutID: workoutID,
                    points: points
                )
            )
        } catch {
            return .failure(error)
        }
    }

    private func fetchRoutes(
        for workoutIDs: [UUID],
        concurrencyLimit: Int
    ) async -> [(UUID, Result<RunRoute, Error>)] {
        guard !workoutIDs.isEmpty else {
            return []
        }

        let effectiveConcurrencyLimit = max(1, min(concurrencyLimit, workoutIDs.count))

        return await withTaskGroup(of: (UUID, Result<RunRoute, Error>).self) { group in
            var nextIndex = 0
            var results: [(UUID, Result<RunRoute, Error>)] = []

            func submitNextTaskIfNeeded() {
                guard nextIndex < workoutIDs.count else {
                    return
                }

                let workoutID = workoutIDs[nextIndex]
                nextIndex += 1

                group.addTask { [self] in
                    let result = await fetchRoute(for: workoutID)
                    return (workoutID, result)
                }
            }

            for _ in 0..<effectiveConcurrencyLimit {
                submitNextTaskIfNeeded()
            }

            while let result = await group.next() {
                results.append(result)

                if Task.isCancelled {
                    group.cancelAll()
                    continue
                }

                submitNextTaskIfNeeded()
            }

            return results
        }
    }

    private func fetchAverageHeartRates(
        for workouts: [HKWorkout],
        concurrencyLimit: Int
    ) async -> [Double?] {
        guard !workouts.isEmpty else {
            return []
        }

        let effectiveConcurrencyLimit = max(1, min(concurrencyLimit, workouts.count))

        return await withTaskGroup(of: (Int, Double?).self) { group in
            var nextIndex = 0
            var heartRates = Array<Double?>(repeating: nil, count: workouts.count)

            func submitNextTaskIfNeeded() {
                guard nextIndex < workouts.count else {
                    return
                }

                let index = nextIndex
                let workout = workouts[index]
                nextIndex += 1

                group.addTask { [self] in
                    let averageHeartRate = try? await fetchAverageHeartRate(for: workout)
                    return (index, averageHeartRate)
                }
            }

            for _ in 0..<effectiveConcurrencyLimit {
                submitNextTaskIfNeeded()
            }

            while let (index, averageHeartRate) = await group.next() {
                heartRates[index] = averageHeartRate

                if Task.isCancelled {
                    group.cancelAll()
                    continue
                }

                submitNextTaskIfNeeded()
            }

            return heartRates
        }
    }

    private func fetchRunningWorkouts(days: Int, limit: Int) async throws -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let startDate = Calendar.current.date(
            byAdding: .day,
            value: -days,
            to: Date()
        )
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: nil,
            options: [.strictStartDate]
        )
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            runningPredicate,
            datePredicate
        ])
        let newestFirst = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [newestFirst]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func fetchWorkout(id: UUID) async throws -> HKWorkout {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObject(with: id)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let workout = samples?.first as? HKWorkout else {
                    continuation.resume(throwing: HealthKitServiceError.workoutUnavailable)
                    return
                }

                continuation.resume(returning: workout)
            }

            healthStore.execute(query)
        }
    }

    private func fetchAverageHeartRate(for workout: HKWorkout) async throws -> Double? {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let beatsPerMinute = statistics?
                    .averageQuantity()?
                    .doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))

                continuation.resume(returning: beatsPerMinute)
            }

            healthStore.execute(query)
        }
    }

    private func fetchRoutes(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        try await withCheckedThrowingContinuation { continuation in
            let routeType = HKSeriesType.workoutRoute()
            let predicate = HKQuery.predicateForObjects(from: workout)
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }

            healthStore.execute(query)
        }
    }

    private func fetchLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        try await withCheckedThrowingContinuation { continuation in
            var routeLocations: [CLLocation] = []

            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                routeLocations.append(contentsOf: locations ?? [])

                if done {
                    continuation.resume(returning: routeLocations)
                }
            }

            healthStore.execute(query)
        }
    }
}

private actor RunRouteCacheStore {
    enum Entry: Sendable {
        case route(RunRoute)
        case missing(cachedAt: Date)
    }

    private let missingEntryLifetime: TimeInterval = 10 * 60
    private var storage: [UUID: Entry] = [:]

    func value(for workoutID: UUID) -> Entry? {
        guard let entry = storage[workoutID] else {
            return nil
        }

        if case .missing(let cachedAt) = entry,
           Date().timeIntervalSince(cachedAt) >= missingEntryLifetime {
            storage[workoutID] = nil
            return nil
        }

        return entry
    }

    func store(_ entry: Entry, for workoutID: UUID) {
        storage[workoutID] = entry
    }
}

enum HealthKitServiceError: LocalizedError, Equatable {
    case healthDataUnavailable
    case workoutUnavailable
    case routeUnavailable

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data is not available on this device."
        case .workoutUnavailable:
            return "The selected workout could not be found."
        case .routeUnavailable:
            return "This workout does not have route data."
        }
    }
}
