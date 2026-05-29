import Foundation

public struct RhythmReleaseInfo: Equatable {
    public let version: String?
    public let build: String?
    public let buildTimestamp: String?
    public let gitCommit: String?

    public init(
        version: String?,
        build: String?,
        buildTimestamp: String?,
        gitCommit: String?
    ) {
        self.version = version
        self.build = build
        self.buildTimestamp = buildTimestamp
        self.gitCommit = gitCommit
    }

    public var versionDisplay: String {
        let visibleVersion = normalized(version) ?? "-"
        guard let build = normalized(build) else {
            return "Version \(visibleVersion)"
        }
        return "Version \(visibleVersion) (\(build))"
    }

    public func buildDisplay(
        language: AppLanguage,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String? {
        guard let timestamp = normalized(buildTimestamp) else {
            return nil
        }

        let date = parsedBuildDate(timestamp)
        let formattedDate = date.map {
            Self.buildDateFormatter(language: language, timeZone: timeZone, locale: locale).string(from: $0)
        } ?? timestamp

        switch language {
        case .chinese:
            let suffix = normalized(gitCommit).map { "（\($0)）" }
            return "构建于 \(formattedDate)\(suffix ?? "")"
        case .english:
            let suffix = normalized(gitCommit).map { "(\($0))" }
            return ["Built \(formattedDate)", suffix].compactMap(\.self).joined(separator: " ")
        }
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> RhythmReleaseInfo {
        RhythmReleaseInfo(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            buildTimestamp: bundle.object(forInfoDictionaryKey: "RhythmBuildTimestamp") as? String,
            gitCommit: bundle.object(forInfoDictionaryKey: "RhythmGitCommit") as? String
        )
    }

    private func parsedBuildDate(_ timestamp: String) -> Date? {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: timestamp)
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "unknown" else { return nil }
        return trimmed
    }

    private static func buildDateFormatter(
        language: AppLanguage,
        timeZone: TimeZone,
        locale: Locale
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = locale
        switch language {
        case .chinese:
            formatter.locale = Locale(identifier: "zh_Hans")
            formatter.dateFormat = "yyyy年M月d日 HH:mm"
        case .english:
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "MMM d, yyyy HH:mm"
        }
        return formatter
    }
}

public enum RhythmUpdateDisabledReason: Equatable {
    case localBuild
    case unsignedBuild
    case unsupportedBuild
}

public enum RhythmUpdateAvailability: Equatable {
    case available
    case disabled(RhythmUpdateDisabledReason)

    public func localizedMessage(language: AppLanguage) -> String {
        switch self {
        case .available:
            switch language {
            case .chinese:
                return "直接发布版本可检查更新。"
            case .english:
                return "Direct-release updates are available."
            }
        case .disabled(.localBuild):
            switch language {
            case .chinese:
                return "当前本地构建暂不支持更新。"
            case .english:
                return "Updates are unavailable in this local build."
            }
        case .disabled(.unsignedBuild):
            switch language {
            case .chinese:
                return "更新需要已签名的直接发布版本。"
            case .english:
                return "Updates require a signed direct-release build."
            }
        case .disabled(.unsupportedBuild):
            switch language {
            case .chinese:
                return "当前构建暂不支持更新。"
            case .english:
                return "Updates are unavailable in this build."
            }
        }
    }
}
