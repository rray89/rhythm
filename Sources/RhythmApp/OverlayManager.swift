import AppKit
import RhythmCore
import SwiftUI

@MainActor
final class OverlayManager: ObservableObject {
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var isShowing: Bool = false
    @Published private(set) var activeBreakKind: BreakKind = .standard

    var onSkipped: (() -> Void)?
    var onCompleted: (() -> Void)?

    private var overlayWindow: OverlayWindow?
    private var keyMonitor: Any?
    private var countdownTimer: Timer?
    private var focusEnforcerTimer: Timer?
    private var restEndAt: Date?
    private var shownAt: Date?
    private let debugOverlay = ProcessInfo.processInfo.environment["RHYTHM_OVERLAY_DEBUG"] == "1"
    private var originalActivationPolicy: NSApplication.ActivationPolicy?
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func present(restSeconds: Int, breakKind: BreakKind) {
        dismiss()

        let screenFrame = (activeScreen() ?? NSScreen.main ?? NSScreen.screens.first)?.frame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        remainingSeconds = max(1, restSeconds)
        restEndAt = Date().addingTimeInterval(TimeInterval(restSeconds))
        shownAt = Date()
        isShowing = true
        activeBreakKind = breakKind

        let contentView = OverlayView(
            model: self,
            settingsStore: settingsStore,
            skipAction: { [weak self] in self?.skipByEscape() }
        )

        let window = OverlayWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false

        let hostingView = EscapeAwareHostingView(rootView: contentView)
        hostingView.onEscape = { [weak self] in
            self?.skipByEscape()
        }
        window.contentView = hostingView
        window.onEscape = { [weak self] in
            self?.skipByEscape()
        }

        overlayWindow = window
        originalActivationPolicy = NSApp.activationPolicy()
        if originalActivationPolicy != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        activateAndFocus(firstResponder: hostingView)
        log("present frame=\(NSStringFromRect(screenFrame)) key=\(window.isKeyWindow)")
        if debugOverlay {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak window] in
                guard let window else { return }
                print("[RhythmOverlay] post-check visible=\(window.isVisible) key=\(window.isKeyWindow) main=\(window.isMainWindow)")
            }
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 {
                self.skipByEscape()
                return nil
            }
            return event
        }

        startFocusEnforcer()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    func extendRest(by seconds: Int) {
        guard isShowing, seconds > 0 else { return }

        if let restEndAt {
            self.restEndAt = restEndAt.addingTimeInterval(TimeInterval(seconds))
        } else {
            self.restEndAt = Date().addingTimeInterval(TimeInterval(seconds))
        }

        remainingSeconds = max(1, remainingSeconds + seconds)
        log("extend rest by \(seconds)s remaining=\(remainingSeconds)")
    }

    func dismiss() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        focusEnforcerTimer?.invalidate()
        focusEnforcerTimer = nil
        restEndAt = nil
        shownAt = nil

        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil

        overlayWindow?.orderOut(nil)
        overlayWindow = nil

        if let originalActivationPolicy, originalActivationPolicy != NSApp.activationPolicy() {
            NSApp.setActivationPolicy(originalActivationPolicy)
        }
        originalActivationPolicy = nil

        isShowing = false
        remainingSeconds = 0
        activeBreakKind = .standard
        log("dismiss")
    }

    func skipByEscape() {
        guard isShowing else { return }
        if let shownAt, Date().timeIntervalSince(shownAt) < 0.2 {
            log("ignore esc (debounce)")
            return
        }
        log("skip by esc")
        dismiss()
        onSkipped?()
    }

    private func tick() {
        guard let restEndAt else { return }
        let nextRemaining = max(0, Int(ceil(restEndAt.timeIntervalSinceNow)))
        remainingSeconds = nextRemaining

        if nextRemaining == 0 {
            dismiss()
            onCompleted?()
        }
    }

    private func startFocusEnforcer() {
        focusEnforcerTimer?.invalidate()
        focusEnforcerTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard
                    let self,
                    self.isShowing,
                    let window = self.overlayWindow
                else { return }

                if !NSApp.isActive || !window.isKeyWindow {
                    self.log("focus lost -> re-activate")
                    self.activateAndFocus(firstResponder: window.contentView)
                }
            }
        }
        RunLoop.main.add(focusEnforcerTimer!, forMode: .common)
    }

    private func activateAndFocus(firstResponder: NSView?) {
        guard let overlayWindow else { return }
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        overlayWindow.makeKeyAndOrderFront(nil)
        overlayWindow.orderFrontRegardless()
        overlayWindow.makeMain()
        if let firstResponder {
            overlayWindow.makeFirstResponder(firstResponder)
        }
        log("activate key=\(overlayWindow.isKeyWindow) main=\(overlayWindow.isMainWindow)")
    }

    private func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }
    }

    private func log(_ message: String) {
        guard debugOverlay else { return }
        print("[RhythmOverlay] \(message)")
    }
}

private struct OverlayView: View {
    @ObservedObject var model: OverlayManager
    @ObservedObject var settingsStore: SettingsStore
    let skipAction: () -> Void

    private var strings: AppStrings {
        AppStrings(language: settingsStore.effectiveAppLanguage)
    }

    private var extensionMinutes: [Int] {
        model.activeBreakKind.extensionMinutes
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text(strings.activeBreakTitle(for: model.activeBreakKind))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(strings.countdownLabel(seconds: model.remainingSeconds))
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text(strings.pressEscapeToEndBreak(for: model.activeBreakKind))
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                HStack(spacing: 12) {
                    ForEach(extensionMinutes, id: \.self) { minutes in
                        Button(strings.extendBreakButton(minutes: minutes)) {
                            model.extendRest(by: minutes * 60)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white.opacity(0.22))
                    }
                }

                Button(strings.endBreakButton(for: model.activeBreakKind)) {
                    skipAction()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))
            }
        }
    }

}

private final class OverlayWindow: NSWindow {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}

private final class EscapeAwareHostingView<Content: View>: NSHostingView<Content> {
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}

extension OverlayManager: RestOverlaying {}
