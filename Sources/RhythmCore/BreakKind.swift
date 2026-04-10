import Foundation

public enum BreakKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case meal
    case gym
    case nap
    case errand
    case duolingo
    case walk

    public var id: String { rawValue }

    public var extensionMinutes: [Int] {
        switch self {
        case .standard:
            return [1, 5]
        case .duolingo, .walk:
            return [5, 10]
        case .meal, .gym, .nap, .errand:
            return [15, 30]
        }
    }
}

public struct BreakPreset: Codable, Hashable, Identifiable, Sendable {
    public let kind: BreakKind
    public let durationSeconds: Int

    public init(kind: BreakKind, durationSeconds: Int) {
        self.kind = kind
        self.durationSeconds = durationSeconds
    }

    public var id: String {
        "\(kind.rawValue)-\(durationSeconds)"
    }
}

public extension BreakPreset {
    static let longBreaks: [BreakPreset] = [
        BreakPreset(kind: .meal, durationSeconds: 45 * 60),
        BreakPreset(kind: .gym, durationSeconds: 2 * 60 * 60),
        BreakPreset(kind: .nap, durationSeconds: 45 * 60),
        BreakPreset(kind: .errand, durationSeconds: 45 * 60),
        BreakPreset(kind: .duolingo, durationSeconds: 10 * 60),
        BreakPreset(kind: .walk, durationSeconds: 20 * 60)
    ]
}
