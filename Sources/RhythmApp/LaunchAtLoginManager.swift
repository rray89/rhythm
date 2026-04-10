import Foundation
import RhythmCore
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isApplying = false
    @Published private(set) var isToggleDisabled = false
    @Published private(set) var statusState: LaunchAtLoginStatusState?

    private let legacyLaunchAgentLabel = "com.xiao2dou.rhythm.launch-at-login"
    private let launchctlPath = "/bin/launchctl"
    private let legacyLaunchAgentURL: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        legacyLaunchAgentURL = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(legacyLaunchAgentLabel).plist", isDirectory: false)
        cleanupLegacyLaunchAgentIfNeeded()
        refreshStatus()
    }

    func setEnabled(_ enabled: Bool) {
        guard !isApplying else { return }
        guard !isToggleDisabled else {
            refreshStatus()
            return
        }

        isApplying = true
        defer { isApplying = false }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshStatus()
        } catch {
            refreshStatus()
            statusState = .setFailed
        }
    }

    func refreshStatus() {
        guard isInstalledInApplications else {
            isEnabled = false
            isToggleDisabled = true
            statusState = .moveToApplicationsRequired
            return
        }

        isToggleDisabled = false
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            isEnabled = true
            statusState = nil
        case .requiresApproval:
            isEnabled = true
            statusState = .approvalRequired
        case .notRegistered:
            isEnabled = false
            statusState = nil
        case .notFound:
            isEnabled = false
            statusState = .unavailable
        @unknown default:
            isEnabled = false
            statusState = .unknown
        }
    }

    private var isInstalledInApplications: Bool {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        guard bundleURL.pathExtension == "app" else {
            return false
        }

        let appPath = bundleURL.path
        if appPath == "/Applications/Rhythm.app" || appPath.hasPrefix("/Applications/") {
            return true
        }

        let userApplicationsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .path + "/"
        return appPath.hasPrefix(userApplicationsPath)
    }

    private func cleanupLegacyLaunchAgentIfNeeded() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyLaunchAgentURL.path) else { return }

        let domain = "gui/\(getuid())"
        _ = runLaunchctl(arguments: ["bootout", domain, legacyLaunchAgentURL.path])

        do {
            try fm.removeItem(at: legacyLaunchAgentURL)
        } catch {
            // Ignore cleanup failure to avoid blocking startup.
        }
    }

    private func runLaunchctl(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchctlPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
