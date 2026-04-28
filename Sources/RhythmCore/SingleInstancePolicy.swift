import Foundation

public struct RunningApplicationSnapshot: Equatable, Sendable {
    public let processIdentifier: Int32
    public let bundleIdentifier: String?
    public let localizedName: String?
    public let executableLastPathComponent: String?

    public init(
        processIdentifier: Int32,
        bundleIdentifier: String?,
        localizedName: String?,
        executableLastPathComponent: String?
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
        self.executableLastPathComponent = executableLastPathComponent
    }
}

public struct SingleInstancePolicy: Sendable {
    private let bundleIdentifier: String?
    private let executableName: String
    private let processIdentifier: Int32

    public init(
        bundleIdentifier: String?,
        executableName: String,
        processIdentifier: Int32
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.executableName = executableName
        self.processIdentifier = processIdentifier
    }

    public func existingInstance(in runningApplications: [RunningApplicationSnapshot]) -> RunningApplicationSnapshot? {
        runningApplications.first { application in
            guard application.processIdentifier != processIdentifier else {
                return false
            }

            if let bundleIdentifier, application.bundleIdentifier == bundleIdentifier {
                return true
            }

            return application.localizedName == executableName
                || application.executableLastPathComponent == executableName
        }
    }
}
