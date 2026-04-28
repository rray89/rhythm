import RhythmCore
import UserNotifications

@MainActor
final class BreakNotificationManager: BreakCompletionNotifying {
    private let settingsStore: SettingsStore
    private let notificationCenterProvider: (() -> UNUserNotificationCenter)?
    private let canUseUserNotifications: () -> Bool

    init(
        settingsStore: SettingsStore,
        notificationCenterProvider: (() -> UNUserNotificationCenter)? = nil,
        canUseUserNotifications: (() -> Bool)? = nil
    ) {
        self.settingsStore = settingsStore
        self.notificationCenterProvider = notificationCenterProvider
        self.canUseUserNotifications = canUseUserNotifications ?? {
            NotificationRuntimePolicy.canUseUserNotifications(
                bundleIdentifier: Bundle.main.bundleIdentifier,
                bundleURL: Bundle.main.bundleURL
            )
        }
    }

    func notifyBreakCompleted(kind: BreakKind) {
        sendNotification(
            identifierPrefix: "rhythm.break.\(kind.rawValue)",
            title: { $0.breakCompletedNotificationTitle(for: kind) },
            body: { $0.breakCompletedNotificationBody(for: kind) }
        )
    }

    func notifyFocusEndingSoon(remainingSeconds: Int) {
        sendNotification(
            identifierPrefix: "rhythm.focus-ending-soon",
            title: { $0.focusEndingSoonNotificationTitle },
            body: { $0.focusEndingSoonNotificationBody(remainingSeconds: remainingSeconds) }
        )
    }

    private func sendNotification(
        identifierPrefix: String,
        title: @escaping (AppStrings) -> String,
        body: @escaping (AppStrings) -> String
    ) {
        guard canUseUserNotifications() else {
            return
        }

        Task {
            let notificationCenter = resolvedNotificationCenter()
            guard await ensureAuthorization() else { return }

            let strings = AppStrings(language: settingsStore.effectiveAppLanguage)
            let content = UNMutableNotificationContent()
            content.title = title(strings)
            content.body = body(strings)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix).\(UUID().uuidString)",
                content: content,
                trigger: nil
            )

            try? await notificationCenter.add(request)
        }
    }

    private func ensureAuthorization() async -> Bool {
        let notificationCenter = resolvedNotificationCenter()
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await notificationCenter.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func resolvedNotificationCenter() -> UNUserNotificationCenter {
        if let notificationCenterProvider {
            return notificationCenterProvider()
        }
        return UNUserNotificationCenter.current()
    }
}
