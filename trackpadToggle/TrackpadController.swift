/*
 * trackpadToggle - Touch Bar trackpad toggle
 * Copyright (C) 2026
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import Cocoa
import CoreGraphics

/// Controls trackpad enable/disable state using CGEventTap.
/// This approach intercepts trackpad events at the Core Graphics level,
/// blocking them before they reach applications.
final class TrackpadController {

    /// Shared singleton instance
    static let shared = TrackpadController()

    /// Current trackpad enabled state
    private(set) var isTrackpadEnabled: Bool = true

    /// The event tap for intercepting trackpad events
    private var eventTap: CFMachPort?

    /// Run loop source for the event tap
    private var runLoopSource: CFRunLoopSource?

    /// Callback invoked when trackpad state changes
    var onStateChange: ((Bool) -> Void)?

    private init() {}

    /// Check if accessibility permissions are granted
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
    }

    /// Request accessibility permissions (shows system dialog)
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Toggle trackpad enabled state
    func toggle() {
        if isTrackpadEnabled {
            disableTrackpad()
        } else {
            enableTrackpad()
        }
    }

    /// Enable the trackpad (stop blocking events)
    func enableTrackpad() {
        guard !isTrackpadEnabled else { return }

        stopEventTap()
        isTrackpadEnabled = true
        onStateChange?(true)
    }

    /// Disable the trackpad (start blocking events)
    func disableTrackpad() {
        guard isTrackpadEnabled else { return }

        if !hasAccessibilityPermission {
            requestAccessibilityPermission()
            return
        }

        if startEventTap() {
            isTrackpadEnabled = false
            onStateChange?(false)
        }
    }

    /// Start the event tap to block trackpad events
    private func startEventTap() -> Bool {
        // Events to intercept from trackpad - built incrementally to help Swift type checker
        var eventMask: CGEventMask = 0
        eventMask |= (1 << CGEventType.leftMouseDown.rawValue)
        eventMask |= (1 << CGEventType.leftMouseUp.rawValue)
        eventMask |= (1 << CGEventType.rightMouseDown.rawValue)
        eventMask |= (1 << CGEventType.rightMouseUp.rawValue)
        eventMask |= (1 << CGEventType.mouseMoved.rawValue)
        eventMask |= (1 << CGEventType.leftMouseDragged.rawValue)
        eventMask |= (1 << CGEventType.rightMouseDragged.rawValue)
        eventMask |= (1 << CGEventType.scrollWheel.rawValue)
        eventMask |= (1 << CGEventType.otherMouseDown.rawValue)
        eventMask |= (1 << CGEventType.otherMouseUp.rawValue)
        eventMask |= (1 << CGEventType.otherMouseDragged.rawValue)

        // Create event tap at session level
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: TrackpadController.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("TrackpadController: Failed to create event tap. Check accessibility permissions.")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("TrackpadController: Event tap started, trackpad disabled")
        return true
    }

    /// Stop the event tap
    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        NSLog("TrackpadController: Event tap stopped, trackpad enabled")
    }

    /// Event tap callback - blocks all intercepted events
    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        // Handle tap disabled by timeout (re-enable it)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let refcon = refcon {
                let controller = Unmanaged<TrackpadController>.fromOpaque(refcon).takeUnretainedValue()
                if let tap = controller.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                    NSLog("TrackpadController: Re-enabled event tap after timeout")
                }
            }
            return Unmanaged.passUnretained(event)
        }

        // Block the event by returning nil
        return nil
    }

    deinit {
        enableTrackpad()
    }
}
