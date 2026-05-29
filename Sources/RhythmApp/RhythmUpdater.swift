import AppKit
import Combine
import RhythmCore
import Security

#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
protocol UpdaterProviding: AnyObject {
    var availability: RhythmUpdateAvailability { get }
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }
    var canCheckForUpdates: Bool { get }
    var isUpdateReadyToInstall: Bool { get }
    var objectWillChange: ObservableObjectPublisher { get }

    func checkForUpdates()
    func installUpdate()
}

@MainActor
final class DisabledUpdaterController: ObservableObject, UpdaterProviding {
    let availability: RhythmUpdateAvailability
    @Published var automaticallyChecksForUpdates: Bool = false
    @Published var automaticallyDownloadsUpdates: Bool = false
    @Published var canCheckForUpdates: Bool = false
    @Published var isUpdateReadyToInstall: Bool = false

    init(reason: RhythmUpdateDisabledReason) {
        availability = .disabled(reason)
    }

    func checkForUpdates() {}
    func installUpdate() {}
}

#if canImport(Sparkle)
@MainActor
final class SparkleUpdaterController: NSObject, ObservableObject, UpdaterProviding, SPUUpdaterDelegate {
    private final class ImmediateInstallHandler: @unchecked Sendable {
        private let handler: () -> Void

        init(_ handler: @escaping () -> Void) {
            self.handler = handler
        }

        func install() {
            handler()
        }
    }

    private lazy var standardController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: nil
    )
    private var cancellable: NSKeyValueObservation?
    private var immediateInstallHandler: ImmediateInstallHandler?

    let availability: RhythmUpdateAvailability = .available
    @Published var canCheckForUpdates: Bool = false
    @Published var isUpdateReadyToInstall: Bool = false

    init(savedAutomaticUpdates: Bool) {
        super.init()
        let updater = standardController.updater
        updater.automaticallyChecksForUpdates = savedAutomaticUpdates
        updater.automaticallyDownloadsUpdates = savedAutomaticUpdates
        canCheckForUpdates = updater.canCheckForUpdates
        cancellable = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
        standardController.startUpdater()
    }

    var automaticallyChecksForUpdates: Bool {
        get { standardController.updater.automaticallyChecksForUpdates }
        set {
            standardController.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { standardController.updater.automaticallyDownloadsUpdates }
        set {
            standardController.updater.automaticallyDownloadsUpdates = newValue
            objectWillChange.send()
        }
    }

    func checkForUpdates() {
        standardController.checkForUpdates(nil)
    }

    func installUpdate() {
        guard let immediateInstallHandler else {
            checkForUpdates()
            return
        }
        immediateInstallHandler.install()
    }

    nonisolated func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        _ = updater
        _ = item
        let handler = ImmediateInstallHandler(immediateInstallHandler)
        Task { @MainActor in
            self.immediateInstallHandler = handler
            self.isUpdateReadyToInstall = true
        }
        return true
    }

    nonisolated func updater(
        _ updater: SPUUpdater,
        userDidMake choice: SPUUserUpdateChoice,
        forUpdate updateItem: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        _ = updater
        _ = updateItem
        let downloaded = state.stage == .downloaded
        Task { @MainActor in
            switch choice {
            case .install, .skip:
                self.immediateInstallHandler = nil
                self.isUpdateReadyToInstall = false
            case .dismiss:
                self.isUpdateReadyToInstall = downloaded
            @unknown default:
                self.immediateInstallHandler = nil
                self.isUpdateReadyToInstall = false
            }
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        _ = updater
        _ = item
        _ = error
        Task { @MainActor in
            self.immediateInstallHandler = nil
            self.isUpdateReadyToInstall = false
        }
    }

    nonisolated func userDidCancelDownload(_ updater: SPUUpdater) {
        _ = updater
        Task { @MainActor in
            self.immediateInstallHandler = nil
            self.isUpdateReadyToInstall = false
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        _ = updater
        _ = error
        Task { @MainActor in
            self.immediateInstallHandler = nil
            self.isUpdateReadyToInstall = false
        }
    }
}
#endif

@MainActor
func makeRhythmUpdaterController() -> UpdaterProviding {
    let bundleURL = Bundle.main.bundleURL
    guard bundleURL.pathExtension == "app" else {
        return DisabledUpdaterController(reason: .localBuild)
    }

    guard isDeveloperIDSigned(bundleURL: bundleURL) else {
        return DisabledUpdaterController(reason: .unsignedBuild)
    }

    #if canImport(Sparkle)
    let defaults = UserDefaults.standard
    let key = "rhythmAutoUpdateEnabled"
    let savedAutomaticUpdates = (defaults.object(forKey: key) as? Bool) ?? true
    return SparkleUpdaterController(savedAutomaticUpdates: savedAutomaticUpdates)
    #else
    return DisabledUpdaterController(reason: .unsupportedBuild)
    #endif
}

private func isDeveloperIDSigned(bundleURL: URL) -> Bool {
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
          let code = staticCode else { return false }

    var info: CFDictionary?
    guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
          let signingInfo = info as? [String: Any],
          let certificates = signingInfo[kSecCodeInfoCertificates as String] as? [SecCertificate],
          let leaf = certificates.first,
          let summary = SecCertificateCopySubjectSummary(leaf) as String?
    else {
        return false
    }

    return summary.hasPrefix("Developer ID Application:")
}
