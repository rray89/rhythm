import AppKit
import Foundation
import RhythmCore

@MainActor
final class LockMonitor {
    var onScreenLocked: (() -> Void)?
    var onScreenUnlocked: (() -> Void)?

    private let distributedNotificationCenter = DistributedNotificationCenter.default()

    func start() {
        distributedNotificationCenter.addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        distributedNotificationCenter.addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
    }

    func stop() {
        distributedNotificationCenter.removeObserver(self)
    }

    @objc private func handleScreenLocked() {
        onScreenLocked?()
    }

    @objc private func handleScreenUnlocked() {
        onScreenUnlocked?()
    }
}

extension LockMonitor: ScreenLockMonitoring {}
