import Foundation

// MARK: - Exercise taxonomy

enum ExerciseCategory: String, Codable, CaseIterable, Identifiable {
    case strength, bodyweight, cardio, running, mobility, stretching, rehabilitation, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .bodyweight: return "Bodyweight"
        case .cardio: return "Cardio"
        case .running: return "Running"
        case .mobility: return "Mobility"
        case .stretching: return "Stretching"
        case .rehabilitation: return "Rehab"
        case .custom: return "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .bodyweight: return "figure.strengthtraining.functional"
        case .cardio: return "heart.fill"
        case .running: return "figure.run"
        case .mobility: return "figure.flexibility"
        case .stretching: return "figure.cooldown"
        case .rehabilitation: return "cross.case.fill"
        case .custom: return "square.grid.2x2"
        }
    }
}

/// Built-in muscle groups. Stored as raw strings so the user can add custom groups.
enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, forearms, core
    case quads, hamstrings, glutes, calves, adductors, hipFlexors, fullBody, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .biceps: return "Biceps"
        case .triceps: return "Triceps"
        case .forearms: return "Forearms"
        case .core: return "Core"
        case .quads: return "Quads"
        case .hamstrings: return "Hamstrings"
        case .glutes: return "Glutes"
        case .calves: return "Calves"
        case .adductors: return "Adductors"
        case .hipFlexors: return "Hip Flexors"
        case .fullBody: return "Full Body"
        case .other: return "Other"
        }
    }

    /// Display name for a raw value that may be a custom user-defined group.
    static func displayName(for raw: String) -> String {
        MuscleGroup(rawValue: raw)?.displayName ?? raw.capitalized
    }
}

enum EquipmentType: String, Codable, CaseIterable, Identifiable {
    case barbell, dumbbell, kettlebell, machine, cable, bodyweight, band, bench, box, none, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .kettlebell: return "Kettlebell"
        case .machine: return "Machine"
        case .cable: return "Cable"
        case .bodyweight: return "Bodyweight"
        case .band: return "Band"
        case .bench: return "Bench"
        case .box: return "Box"
        case .none: return "No Equipment"
        case .other: return "Other"
        }
    }

    static func displayName(for raw: String) -> String {
        EquipmentType(rawValue: raw)?.displayName ?? raw.capitalized
    }
}

enum MovementPattern: String, Codable, CaseIterable, Identifiable {
    case horizontalPush, horizontalPull, verticalPush, verticalPull
    case squat, hinge, lunge, carry, rotation, isolation, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .horizontalPush: return "Horizontal Push"
        case .horizontalPull: return "Horizontal Pull"
        case .verticalPush: return "Vertical Push"
        case .verticalPull: return "Vertical Pull"
        case .squat: return "Squat"
        case .hinge: return "Hinge"
        case .lunge: return "Lunge"
        case .carry: return "Carry"
        case .rotation: return "Rotation"
        case .isolation: return "Isolation"
        case .other: return "Other"
        }
    }
}

// MARK: - Sets

enum SetType: String, Codable, CaseIterable, Identifiable {
    case warmup, working, backoff, dropSet, failure, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warmup: return "Warm-up"
        case .working: return "Working"
        case .backoff: return "Back-off"
        case .dropSet: return "Drop Set"
        case .failure: return "Failure"
        case .custom: return "Custom"
        }
    }

    var shortLabel: String {
        switch self {
        case .warmup: return "W"
        case .working: return ""
        case .backoff: return "B"
        case .dropSet: return "D"
        case .failure: return "F"
        case .custom: return "C"
        }
    }

    /// Working-type sets count toward volume and PR detection.
    var countsAsWorking: Bool {
        switch self {
        case .warmup: return false
        default: return true
        }
    }
}

// MARK: - Sessions

enum SessionStatus: String, Codable {
    case active, paused, completed, discarded
}

// MARK: - Running

enum RunType: String, Codable, CaseIterable, Identifiable {
    case easy, tempo, interval, timeTrial, recovery, long, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy Run"
        case .tempo: return "Tempo Run"
        case .interval: return "Intervals"
        case .timeTrial: return "Time Trial"
        case .recovery: return "Recovery Run"
        case .long: return "Long Run"
        case .custom: return "Custom"
        }
    }

    static func displayName(for raw: String) -> String {
        RunType(rawValue: raw)?.displayName ?? raw.capitalized
    }
}

enum RunSurface: String, Codable, CaseIterable, Identifiable {
    case road, track, trail, treadmill, grass, other

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum RouteType: String, Codable, CaseIterable, Identifiable {
    case loop, outAndBack, pointToPoint, laps, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .loop: return "Loop"
        case .outAndBack: return "Out & Back"
        case .pointToPoint: return "Point to Point"
        case .laps: return "Laps"
        case .other: return "Other"
        }
    }
}

/// Standard benchmark distances tracked for personal-best times.
enum BenchmarkDistance: Double, CaseIterable, Identifiable {
    case sprint100m = 100
    case oneK = 1000
    case threeK = 3000
    case fiveK = 5000
    case tenK = 10000

    var id: Double { rawValue }
    var meters: Double { rawValue }

    var displayName: String {
        switch self {
        case .sprint100m: return "100 m"
        case .oneK: return "1 km"
        case .threeK: return "3 km"
        case .fiveK: return "5 km"
        case .tenK: return "10 km"
        }
    }

    /// Distance tolerance used when matching a logged run to this benchmark.
    var tolerance: Double {
        switch self {
        case .sprint100m: return 5
        case .oneK: return 30
        case .threeK: return 75
        case .fiveK: return 120
        case .tenK: return 250
        }
    }
}

// MARK: - Flexibility

enum FlexibilityKind: String, Codable, CaseIterable, Identifiable {
    case frontSplit, middleSplit, mobility, recovery, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .frontSplit: return "Front Split"
        case .middleSplit: return "Middle Split"
        case .mobility: return "Mobility"
        case .recovery: return "Recovery"
        case .custom: return "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .frontSplit: return "figure.flexibility"
        case .middleSplit: return "figure.yoga"
        case .mobility: return "figure.cooldown"
        case .recovery: return "leaf.fill"
        case .custom: return "sparkles"
        }
    }
}

enum SideMode: String, Codable, CaseIterable, Identifiable {
    case bilateral, leftRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bilateral: return "Both Sides Together"
        case .leftRight: return "Left / Right Separately"
        }
    }
}

enum SplitTarget: String, Codable, CaseIterable, Identifiable {
    case leftFront, rightFront, middle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leftFront: return "Left Front Split"
        case .rightFront: return "Right Front Split"
        case .middle: return "Middle Split"
        }
    }
}

enum FlexibilityMetricMethod: String, Codable, CaseIterable, Identifiable {
    case floorDistance, hipHeight, blockHeight, angle, subjectiveScore

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .floorDistance: return "Distance from Floor"
        case .hipHeight: return "Hip Height"
        case .blockHeight: return "Block Height"
        case .angle: return "Angle"
        case .subjectiveScore: return "Subjective Score"
        }
    }

    var unitLabel: String {
        switch self {
        case .floorDistance, .hipHeight, .blockHeight: return "cm"
        case .angle: return "°"
        case .subjectiveScore: return "/10"
        }
    }

    /// Lower is better for height-from-floor style measurements; higher is better for angle and score.
    var lowerIsBetter: Bool {
        switch self {
        case .floorDistance, .hipHeight, .blockHeight: return true
        case .angle, .subjectiveScore: return false
        }
    }
}

// MARK: - Schedule

enum ActivityKind: String, Codable, CaseIterable, Identifiable {
    case strength, running, frontSplit, middleSplit, mobility, recovery, rest, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .running: return "Running"
        case .frontSplit: return "Front Split"
        case .middleSplit: return "Middle Split"
        case .mobility: return "Mobility"
        case .recovery: return "Recovery"
        case .rest: return "Rest Day"
        case .custom: return "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .running: return "figure.run"
        case .frontSplit: return "figure.flexibility"
        case .middleSplit: return "figure.yoga"
        case .mobility: return "figure.cooldown"
        case .recovery: return "leaf.fill"
        case .rest: return "moon.zzz.fill"
        case .custom: return "star.fill"
        }
    }

    static func displayName(for raw: String) -> String {
        ActivityKind(rawValue: raw)?.displayName ?? raw.capitalized
    }

    static func symbolName(for raw: String) -> String {
        ActivityKind(rawValue: raw)?.symbolName ?? "star.fill"
    }
}

enum ScheduledStatus: String, Codable {
    case planned, completed, skipped, moved
}

// MARK: - Body

enum BodyMetric: String, Codable, CaseIterable, Identifiable {
    case bodyWeight, bodyFat, waist, chest, shoulders, neck
    case leftArm, rightArm, leftThigh, rightThigh, leftCalf, rightCalf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyWeight: return "Body Weight"
        case .bodyFat: return "Body Fat %"
        case .waist: return "Waist"
        case .chest: return "Chest"
        case .shoulders: return "Shoulders"
        case .neck: return "Neck"
        case .leftArm: return "Left Arm"
        case .rightArm: return "Right Arm"
        case .leftThigh: return "Left Thigh"
        case .rightThigh: return "Right Thigh"
        case .leftCalf: return "Left Calf"
        case .rightCalf: return "Right Calf"
        }
    }

    /// Whether the metric is a mass (kg), percentage, or length (cm).
    var isMass: Bool { self == .bodyWeight }
    var isPercent: Bool { self == .bodyFat }

    static let customPrefix = "custom:"

    static func displayName(for raw: String) -> String {
        if let metric = BodyMetric(rawValue: raw) { return metric.displayName }
        if raw.hasPrefix(customPrefix) { return String(raw.dropFirst(customPrefix.count)) }
        return raw.capitalized
    }
}

// MARK: - Photos

enum PhotoAngle: String, Codable, CaseIterable, Identifiable {
    case front, side, back, custom

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

// MARK: - Personal records

enum PRKind: String, Codable, CaseIterable {
    case heaviestWeight, repsAtWeight, estimatedOneRM, sessionVolume
    case fastestTime, bestPace, longestRun
    case bestFrontSplitLeft, bestFrontSplitRight, bestMiddleSplit
    case longestStreak

    var displayName: String {
        switch self {
        case .heaviestWeight: return "Heaviest Weight"
        case .repsAtWeight: return "Most Reps at Weight"
        case .estimatedOneRM: return "Estimated 1RM"
        case .sessionVolume: return "Highest Session Volume"
        case .fastestTime: return "Fastest Time"
        case .bestPace: return "Best Pace"
        case .longestRun: return "Longest Run"
        case .bestFrontSplitLeft: return "Best Left Front Split"
        case .bestFrontSplitRight: return "Best Right Front Split"
        case .bestMiddleSplit: return "Best Middle Split"
        case .longestStreak: return "Longest Streak"
        }
    }
}

// MARK: - Insights

enum InsightCategory: String, Codable, CaseIterable, Identifiable {
    case progressiveOverload, stalling, highFatigue, deload, consistency
    case muscleBalance, running, flexibility, schedule, projection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .progressiveOverload: return "Progressive Overload"
        case .stalling: return "Stalled Exercises"
        case .highFatigue: return "Fatigue & RPE"
        case .deload: return "Recovery Weeks"
        case .consistency: return "Consistency"
        case .muscleBalance: return "Muscle Balance"
        case .running: return "Running"
        case .flexibility: return "Flexibility"
        case .schedule: return "Schedule"
        case .projection: return "Projections"
        }
    }

    var symbolName: String {
        switch self {
        case .progressiveOverload: return "arrow.up.right.circle.fill"
        case .stalling: return "pause.circle.fill"
        case .highFatigue: return "gauge.with.needle.fill"
        case .deload: return "arrow.down.circle.fill"
        case .consistency: return "calendar.badge.checkmark"
        case .muscleBalance: return "scalemass.fill"
        case .running: return "figure.run.circle.fill"
        case .flexibility: return "figure.flexibility"
        case .schedule: return "calendar.badge.exclamationmark"
        case .projection: return "chart.line.uptrend.xyaxis.circle.fill"
        }
    }
}

// MARK: - Units

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms, pounds

    var id: String { rawValue }
    var displayName: String { self == .kilograms ? "Kilograms (kg)" : "Pounds (lb)" }
    var suffix: String { self == .kilograms ? "kg" : "lb" }
}

enum DistanceUnit: String, Codable, CaseIterable, Identifiable {
    case kilometers, miles

    var id: String { rawValue }
    var displayName: String { self == .kilometers ? "Kilometers (km)" : "Miles (mi)" }
    var suffix: String { self == .kilometers ? "km" : "mi" }
}

enum LengthUnit: String, Codable, CaseIterable, Identifiable {
    case centimeters, inches

    var id: String { rawValue }
    var displayName: String { self == .centimeters ? "Centimeters (cm)" : "Inches (in)" }
    var suffix: String { self == .centimeters ? "cm" : "in" }
}

enum AppAppearance: String, Codable, CaseIterable, Identifiable {
    case dark, system

    var id: String { rawValue }
    var displayName: String { self == .dark ? "Forge Dark" : "Match System" }
}
