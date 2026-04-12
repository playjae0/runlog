import CoreLocation
import HealthKit
import Foundation

enum HealthAuthorizationResult {
    case unavailable
    case requestCompleted
    case failed(String)
}

struct RunningWorkoutSummary: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distanceMeters: Double?
}

final class HealthKitService {
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

        do {
            // HealthKit does not reveal the exact allow/deny decision for read access.
            // A successful return means the authorization request flow completed.
            try await healthStore.requestAuthorization(toShare: [], read: [workoutType, routeType])
            return .requestCompleted
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func fetchRecentRunningWorkouts(limit: Int = HKObjectQueryNoLimit) async -> Result<[RunningWorkoutSummary], Error> {
        guard isHealthDataAvailable else {
            return .failure(HealthKitServiceError.healthDataUnavailable)
        }

        let workoutType = HKObjectType.workoutType()
        let runningPredicate = HKQuery.predicateForWorkouts(with: .running)
        let newestFirst = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: runningPredicate,
                limit: limit,
                sortDescriptors: [newestFirst]
            ) { _, samples, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                    return
                }

                let workouts = (samples as? [HKWorkout]) ?? []
                let summaries = workouts.map { workout in
                    RunningWorkoutSummary(
                        id: workout.uuid,
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        duration: workout.duration,
                        distanceMeters: workout.totalDistance?.doubleValue(for: .meter())
                    )
                }

                continuation.resume(returning: .success(summaries))
            }

            healthStore.execute(query)
        }
    }

    func fetchRoute(for workoutID: UUID) async -> Result<RunRoute, Error> {
        guard isHealthDataAvailable else {
            return .failure(HealthKitServiceError.healthDataUnavailable)
        }

        do {
            let workout = try await fetchWorkout(id: workoutID)
            let routes = try await fetchRoutes(for: workout)

            guard let route = routes.first else {
                return .failure(HealthKitServiceError.routeUnavailable)
            }

            let locations = try await fetchLocations(for: route)
            let points = locations.map { location in
                RunRoutePoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    timestamp: location.timestamp,
                    altitude: location.verticalAccuracy >= 0 ? location.altitude : nil
                )
            }

            return .success(RunRoute(workoutID: workoutID, points: points))
        } catch {
            return .failure(error)
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

enum HealthKitServiceError: LocalizedError {
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
