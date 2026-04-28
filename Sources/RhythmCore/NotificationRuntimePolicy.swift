import Foundation

public enum NotificationRuntimePolicy {
    public static func canUseUserNotifications(
        bundleIdentifier: String?,
        bundleURL: URL
    ) -> Bool {
        guard let bundleIdentifier, bundleIdentifier.contains(".") else {
            return false
        }

        return bundleURL.pathExtension == "app"
    }
}
