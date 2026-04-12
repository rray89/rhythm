import AppKit
import Foundation
import RhythmCore

@MainActor
final class SleepWakeMonitor {
    var onWillSleep: (() -> Void)?
    var onDidWake: (() -> Void)?

    private let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter

    func start() {
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        workspaceNotificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func stop() {
        workspaceNotificationCenter.removeObserver(self)
    }

    @objc private func handleWillSleep() {
        onWillSleep?()
    }

    @objc private func handleDidWake() {
        onDidWake?()
    }
}

extension SleepWakeMonitor: SystemSleepMonitoring {}
