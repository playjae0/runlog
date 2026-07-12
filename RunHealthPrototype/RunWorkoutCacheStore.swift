import Foundation

struct RunWorkoutCache: Sendable {
    let workouts: [RunWorkout]
    let lastRefreshedAt: Date?
}

struct RunWorkoutCacheStore: @unchecked Sendable {
    private struct CachePayload: Codable {
        let schemaVersion: Int
        let workouts: [RunWorkout]
        let lastRefreshedAt: Date
    }

    private let currentSchemaVersion = 1
    private let fileManager: FileManager
    private let fileName = "run-workout-cache.json"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load() -> RunWorkoutCache {
        guard let data = try? Data(contentsOf: cacheURL),
              let payload = try? decoder.decode(CachePayload.self, from: data),
              payload.schemaVersion == currentSchemaVersion else {
            return RunWorkoutCache(workouts: [], lastRefreshedAt: nil)
        }

        return RunWorkoutCache(
            workouts: payload.workouts.sorted { $0.startDate > $1.startDate },
            lastRefreshedAt: payload.lastRefreshedAt
        )
    }

    func save(workouts: [RunWorkout], refreshedAt: Date = Date()) throws {
        try fileManager.createDirectory(
            at: cacheDirectoryURL,
            withIntermediateDirectories: true
        )

        let payload = CachePayload(
            schemaVersion: currentSchemaVersion,
            workouts: workouts.sorted { $0.startDate > $1.startDate },
            lastRefreshedAt: refreshedAt
        )
        let data = try encoder.encode(payload)
        try data.write(to: cacheURL, options: [.atomic])
    }

    private var cacheDirectoryURL: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RunLog", isDirectory: true)
    }

    private var cacheURL: URL {
        cacheDirectoryURL.appendingPathComponent(fileName)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
