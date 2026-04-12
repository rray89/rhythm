import AppKit
import Foundation
import RhythmCore

@MainActor
final class LockMonitor {
    var onScreenLocked: (() -> Void)?
    var onScreenUnlocked: (() -> Void)?

    private(set) var isScreenLocked = false

    private let distributedNotificationCenter = DistributedNotificationCenter.default()
    private let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter

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
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(handleSessionResignedActive),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(handleSessionBecameActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
    }

    func stop() {
        distributedNotificationCenter.removeObserver(self)
        workspaceNotificationCenter.removeObserver(self)
    }

    @objc private func handleScreenLocked() {
        isScreenLocked = true
        onScreenLocked?()
    }

    @objc private func handleScreenUnlocked() {
        isScreenLocked = false
        onScreenUnlocked?()
    }

    @objc private func handleSessionResignedActive() {
        isScreenLocked = true
    }

    @objc private func handleSessionBecameActive() {
        isScreenLocked = false
    }
}

extension LockMonitor: ScreenLockMonitoring {}
