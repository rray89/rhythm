import ApplicationServices
import Foundation

final class EscapeEventTap {
    var onEscape: (() -> Void)?
    private(set) var isEnabled = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start(promptIfNeeded: Bool) {
        stop()

        let options = ["AXTrustedCheckOptionPrompt": promptIfNeeded] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let manager = Unmanaged<EscapeEventTap>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let eventTap = manager.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            if event.getIntegerValueField(.keyboardEventKeycode) == 53 {
                manager.onEscape?()
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: userInfo
        ) else {
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isEnabled = true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        runLoopSource = nil

        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
        }
        eventTap = nil
        isEnabled = false
    }
}
