import RhythmCore
import UserNotifications

@MainActor
final class BreakNotificationManager: BreakCompletionNotifying {
    private let settingsStore: SettingsStore
    private let notificationCenterProvider: (() -> UNUserNotificationCenter)?

    init(
        settingsStore: SettingsStore,
        notificationCenterProvider: (() -> UNUserNotificationCenter)? = nil
    ) {
        self.settingsStore = settingsStore
        self.notificationCenterProvider = notificationCenterProvider
    }

    func notifyBreakCompleted(kind: BreakKind) {
        Task {
            let notificationCenter = resolvedNotificationCenter()
            guard await ensureAuthorization() else { return }

            let strings = AppStrings(language: settingsStore.effectiveAppLanguage)
            let content = UNMutableNotificationContent()
            content.title = strings.breakCompletedNotificationTitle(for: kind)
            content.body = strings.breakCompletedNotificationBody(for: kind)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "rhythm.break.\(kind.rawValue).\(UUID().uuidString)",
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
