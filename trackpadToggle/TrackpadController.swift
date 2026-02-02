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
import IOKit

/// Controls trackpad enable/disable state using CGEventTap.
/// This approach intercepts trackpad events at the Core Graphics level,
/// blocking them before they reach applications while allowing external mice.
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

    /// Timer for retrying after permission grant
    private var permissionCheckTimer: Timer?

    /// Cached set of internal trackpad sender IDs (vendor/product combos)
    private static var internalTrackpadSenderIDs: Set<UInt64> = []

    /// Flag to track if we've initialized trackpad detection
    private static var hasInitializedTrackpadDetection = false

    private init() {
        Self.initializeTrackpadDetection()
    }

    /// Initialize detection of internal trackpad hardware
    private static func initializeTrackpadDetection() {
        guard !hasInitializedTrackpadDetection else { return }
        hasInitializedTrackpadDetection = true

        // Find internal trackpad devices via IOKit
        let matchingDict = IOServiceMatching("AppleMultitouchDevice")
        var iterator: io_iterator_t = 0

        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard result == KERN_SUCCESS else {
            NSLog("TrackpadController: Failed to get matching services for trackpad detection")
            return
        }

        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            // Get device properties
            var properties: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let props = properties?.takeRetainedValue() as? [String: Any] {

                // Check if this is an internal device (built-in trackpad)
                let isInternal = props["Built-In"] as? Bool ?? false
                let productName = props["Product"] as? String ?? ""

                if isInternal || productName.lowercased().contains("trackpad") {
                    // Get vendor and product ID to create a sender ID
                    let vendorID = props["idVendor"] as? Int ?? 0
                    let productID = props["idProduct"] as? Int ?? 0

                    if vendorID != 0 || productID != 0 {
                        let senderID = UInt64(vendorID) << 32 | UInt64(productID)
                        internalTrackpadSenderIDs.insert(senderID)
                        NSLog("TrackpadController: Registered trackpad - \(productName)")
                    }
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        // If no trackpads found via IOKit, use Apple's known trackpad vendor ID
        if internalTrackpadSenderIDs.isEmpty {
            // Apple's vendor ID is 0x05AC (1452), common trackpad product IDs
            let appleVendor: UInt64 = 0x05AC
            internalTrackpadSenderIDs.insert(appleVendor << 32 | 0x0274) // Magic Trackpad
            internalTrackpadSenderIDs.insert(appleVendor << 32 | 0x0265) // Built-in trackpad
            NSLog("TrackpadController: Using default Apple trackpad IDs")
        }
    }

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
        stopPermissionCheckTimer()
        isTrackpadEnabled = true
        onStateChange?(true)
    }

    /// Disable the trackpad (start blocking events)
    func disableTrackpad() {
        guard isTrackpadEnabled else { return }

        if !hasAccessibilityPermission {
            requestAccessibilityPermission()
            startPermissionCheckTimer()
            return
        }

        if startEventTap() {
            isTrackpadEnabled = false
            onStateChange?(false)
        }
    }

    /// Start timer to check for permission grant and retry
    private func startPermissionCheckTimer() {
        stopPermissionCheckTimer()
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.hasAccessibilityPermission {
                self.stopPermissionCheckTimer()
                // Auto-retry disable now that we have permission
                if self.isTrackpadEnabled {
                    self.disableTrackpad()
                }
            }
        }
    }

    /// Stop the permission check timer
    private func stopPermissionCheckTimer() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
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

    /// Check if an event originated from the internal trackpad vs external mouse
    /// Returns true if the event should be blocked (is from trackpad)
    private static func isTrackpadEvent(_ event: CGEvent) -> Bool {
        let eventType = event.type

        // Method 1: Check scroll wheel characteristics
        // Trackpad scrolls have phases (gesture) and are continuous
        // Mouse scrolls are discrete without phases
        if eventType == .scrollWheel {
            let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
            let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
            let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)

            // Any phase or continuous flag = trackpad
            if scrollPhase != 0 || momentumPhase != 0 || isContinuous != 0 {
                return true
            }
            // Discrete scroll (no phases, not continuous) = mouse, allow through
            return false
        }

        // Method 2: Check subtype - subtype 1 indicates tablet/touch events (trackpad)
        let subtype = event.getIntegerValueField(.mouseEventSubtype)
        if subtype == 1 {
            return true
        }

        // Method 3: Check event source state ID
        // The built-in trackpad typically has sourceStateID of 0
        // External USB/Bluetooth mice have non-zero sourceStateID
        let sourceStateID = event.getIntegerValueField(.eventSourceStateID)

        // For movement and click events, use sourceStateID as primary discriminator
        // sourceStateID 0 = likely internal trackpad
        // sourceStateID non-zero = likely external mouse
        if sourceStateID == 0 {
            return true
        }

        // Method 4: Check event source unix process ID
        // If sourceUnixProcessID is 0, it's a hardware event (could be either)
        // This is less reliable but can help in edge cases
        let sourceUnixProcessID = event.getIntegerValueField(.eventSourceUnixProcessID)
        if sourceUnixProcessID == 0 && sourceStateID == 0 {
            return true
        }

        // Default: allow through (external mouse or can't determine)
        return false
    }

    /// Event tap callback - blocks trackpad events, allows external mice
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

        // Check if this event is from the trackpad
        if isTrackpadEvent(event) {
            // Block trackpad events
            return nil
        }

        // Allow external mouse events to pass through
        return Unmanaged.passUnretained(event)
    }

    deinit {
        enableTrackpad()
    }
}
