import Foundation
import SwiftData

/// A single logged run. Distances are stored in meters, durations in seconds.
@Model
final class RunningSession {
    var id: UUID = UUID()
    var date: Date = Date()
    var runTypeRaw: String = RunType.easy.rawValue
    var distanceMeters: Double = 0
    var durationSeconds: TimeInterval = 0
    var surfaceRaw: String = RunSurface.road.rawValue
    var routeTypeRaw: String = RouteType.loop.rawValue
    var rpe: Double?
    var averageHeartRate: Double?
    var calories: Double?
    var notes: String = ""
    /// Free-form description of interval structure, e.g. "6 × 400 m / 90 s rest".
    var intervalStructure: String = ""
    /// "manual" or "healthkit".
    var source: String = "manual"
    /// HealthKit workout UUID, used to prevent duplicate imports.
    var healthKitID: String?

    @Relationship(deleteRule: .cascade, inverse: \RunningSplit.session)
    var splits: [RunningSplit]? = []

    init(date: Date = Date(), runType: RunType = .easy, distanceMeters: Double = 0, durationSeconds: TimeInterval = 0) {
        self.id = UUID()
        self.date = date
        self.runTypeRaw = runType.rawValue
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
    }

    var runType: RunType {
        get { RunType(rawValue: runTypeRaw) ?? .custom }
        set { runTypeRaw = newValue.rawValue }
    }

    /// Average pace in seconds per kilometer; nil when distance is zero.
    var paceSecondsPerKm: Double? {
        RunningMath.paceSecondsPerKm(distanceMeters: distanceMeters, durationSeconds: durationSeconds)
    }

    var orderedSplits: [RunningSplit] {
        (splits ?? []).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// The benchmark distance this run matches, if any (e.g. a 3 km time trial).
    var matchedBenchmark: BenchmarkDistance? {
        BenchmarkDistance.allCases.first { abs(distanceMeters - $0.meters) <= $0.tolerance }
    }
}

@Model
final class RunningSplit {
    var id: UUID = UUID()
    var sortIndex: Int = 0
    var distanceMeters: Double = 1000
    var durationSeconds: TimeInterval = 0

    var session: RunningSession?

    init(sortIndex: Int, distanceMeters: Double = 1000, durationSeconds: TimeInterval = 0) {
        self.id = UUID()
        self.sortIndex = sortIndex
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
    }

    var paceSecondsPerKm: Double? {
        RunningMath.paceSecondsPerKm(distanceMeters: distanceMeters, durationSeconds: durationSeconds)
    }
}
