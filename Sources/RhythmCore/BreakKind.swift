import Foundation

public enum BreakKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case meal
    case gym
    case nap
    case errand
    case desk

    public var id: String { rawValue }

    public var usesBlockingOverlay: Bool {
        switch self {
        case .desk:
            return false
        case .standard, .meal, .gym, .nap, .errand:
            return true
        }
    }

    public var extensionMinutes: [Int] {
        switch self {
        case .standard:
            return [1, 5]
        case .desk:
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
    static let deskBreak = BreakPreset(kind: .desk, durationSeconds: 20 * 60)

    static let longBreaks: [BreakPreset] = [
        deskBreak
    ]
}
