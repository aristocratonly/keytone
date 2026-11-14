import CoreGraphics
import Foundation

enum InputEvent {
    case key(code: UInt16, down: Bool, isRepeat: Bool)
    case mouse(button: Int, down: Bool)
    case scroll
}

/// Global, listen-only event tap: observes keys and mouse, never blocks or alters them.
final class InputMonitor {
    var handler: ((InputEvent) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var modifiersDown = Set<UInt16>()
    private var lastScroll = Date.distantPast
    private var scrollAccum: Double = 0
    private static let detent: Double = 36   // points of travel per click

    private static let modifierMask: [UInt16: CGEventFlags] = [
        56: .maskShift, 60: .maskShift, 59: .maskControl, 62: .maskControl,
        58: .maskAlternate, 61: .maskAlternate, 55: .maskCommand, 54: .maskCommand, 63: .maskSecondaryFn,
    ]

    static var hasKeyboardAccess: Bool { CGPreflightListenEventAccess() }
    static func requestKeyboardAccess() { _ = CGRequestListenEventAccess() }

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        var mask: CGEventMask = 0
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .leftMouseUp,
                                    .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp, .scrollWheel]
        for t in types { mask |= CGEventMask(1) << t.rawValue }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                if let refcon {
                    Unmanaged<InputMonitor>.fromOpaque(refcon).takeUnretainedValue().process(type, event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { Diag.log("tapCreate FAILED"); return false }
        Diag.log("tap started, listenAccess=\(CGPreflightListenEventAccess())")

        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }

    private func process(_ type: CGEventType, _ e: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .keyDown, .keyUp:
            let code = UInt16(e.getIntegerValueField(.keyboardEventKeycode))
            let rep = e.getIntegerValueField(.keyboardEventAutorepeat) != 0
            handler?(.key(code: code, down: type == .keyDown, isRepeat: rep))
        case .flagsChanged:
            let code = UInt16(e.getIntegerValueField(.keyboardEventKeycode))
            if code == 57 {   // Caps Lock: one event per physical press, flag shows lock state, not key state
                handler?(.key(code: code, down: true, isRepeat: false))
                break
            }
            let isDown: Bool
            if let mask = Self.modifierMask[code] {
                isDown = e.flags.contains(mask)
                // with both Shifts held, releasing one keeps the flag: fall back to our own tracking
                if isDown && modifiersDown.contains(code) {
                    modifiersDown.remove(code)
                    handler?(.key(code: code, down: false, isRepeat: false))
                    break
                }
            } else {
                isDown = !modifiersDown.contains(code)
            }
            if isDown { modifiersDown.insert(code) } else { modifiersDown.remove(code) }
            handler?(.key(code: code, down: isDown, isRepeat: false))
        case .leftMouseDown:
            handler?(.mouse(button: 0, down: true))
        case .leftMouseUp: handler?(.mouse(button: 0, down: false))
        case .rightMouseDown: handler?(.mouse(button: 1, down: true))
        case .rightMouseUp: handler?(.mouse(button: 1, down: false))
        case .otherMouseDown: handler?(.mouse(button: 2, down: true))
        case .otherMouseUp: handler?(.mouse(button: 2, down: false))
        case .scrollWheel:
            let now = Date()
            if e.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 {
                // notched mouse wheel: one event per detent -> one click
                if now.timeIntervalSince(lastScroll) > 0.025 { lastScroll = now; handler?(.scroll) }
                break
            }
            // trackpad / smooth / momentum scrolling: click per distance travelled, like virtual detents,
            // so the clicks slow down with the content and stop when it stops
            if e.getIntegerValueField(.scrollWheelEventScrollPhase) == 1 { scrollAccum = 0 }   // gesture began
            let dy = abs(e.getDoubleValueField(.scrollWheelEventPointDeltaAxis1))
            let dx = abs(e.getDoubleValueField(.scrollWheelEventPointDeltaAxis2))
            scrollAccum += max(dx, dy)
            if scrollAccum >= Self.detent {
                scrollAccum = min(scrollAccum - Self.detent, Self.detent)   // a fast flick doesn't bank a backlog of clicks
                if now.timeIntervalSince(lastScroll) > 0.03 { lastScroll = now; handler?(.scroll) }
            }
        default: break
        }
    }
}
