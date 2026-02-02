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
import os.log

private let logger = Logger(subsystem: "com.trackpadToggle.app", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {

    /// Control Strip item identifier
    private static let controlStripIdentifier = NSTouchBarItem.Identifier(
        "com.trackpadToggle.controlstrip"
    )

    /// The Control Strip touch bar item
    private var controlStripItem: NSCustomTouchBarItem?

    /// The button displayed in the Control Strip
    private var toggleButton: NSButton?

    /// Status item for menu bar (provides a way to quit without Touch Bar)
    private var statusItem: NSStatusItem?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.notice("applicationDidFinishLaunching started")

        setupStatusBarMenu()
        let statusDesc = String(describing: self.statusItem)
        logger.notice("setupStatusBarMenu completed, statusItem = \(statusDesc, privacy: .public)")
        setupControlStrip()
        setupTrackpadStateCallback()

        // Check accessibility on launch
        if !TrackpadController.shared.hasAccessibilityPermission {
            logger.warning("Accessibility permission not granted")
        }
        logger.notice("applicationDidFinishLaunching completed")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Ensure trackpad is re-enabled on quit
        TrackpadController.shared.enableTrackpad()
        removeControlStrip()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running as a background app
        false
    }

    // MARK: - Status Bar Menu

    private func setupStatusBarMenu() {
        // Use variable length to ensure visibility even without icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        logger.notice("Created statusItem: \(String(describing: self.statusItem), privacy: .public)")

        if let button = statusItem?.button {
            logger.notice("Got statusItem button")
            // Try custom image first
            if let customImage = NSImage(named: "trackpad_on") {
                logger.notice("Loaded custom image trackpad_on")
                button.image = customImage
                button.image?.isTemplate = true
            } else if let sysImage = NSImage(systemSymbolName: "hand.point.up.fill",
                                              accessibilityDescription: "Trackpad") {
                // Fallback to system image
                logger.notice("Using system symbol fallback")
                button.image = sysImage
            } else {
                // Ultimate fallback - just use text
                logger.warning("No image available, using text title")
                button.title = "TP"
            }
        } else {
            logger.error("statusItem.button is nil!")
        }

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Quit trackpadToggle",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        statusItem?.menu = menu
        logger.notice("Menu configured")
    }

    // MARK: - Control Strip Setup

    private func setupControlStrip() {
        // Enable close box on modal Touch Bar when frontmost
        DFRSystemModalShowsCloseBoxWhenFrontMost(true)

        // Create the Control Strip item
        let item = NSCustomTouchBarItem(identifier: Self.controlStripIdentifier)

        // Create toggle button with initial state icon
        let button = NSButton(
            image: NSImage(named: "trackpad_on") ?? NSImage(),
            target: self,
            action: #selector(toggleTrackpad)
        )
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown

        item.view = button
        toggleButton = button
        controlStripItem = item

        // Add to system tray
        NSTouchBarItem.addSystemTrayItem(item)

        // Enable presence in Control Strip
        DFRElementSetControlStripPresenceForIdentifier(Self.controlStripIdentifier, true)

        NSLog("AppDelegate: Control Strip item added")
    }

    private func removeControlStrip() {
        guard let item = controlStripItem else { return }

        // Disable presence in Control Strip
        DFRElementSetControlStripPresenceForIdentifier(Self.controlStripIdentifier, false)

        // Remove from system tray
        NSTouchBarItem.removeSystemTrayItem(item)

        controlStripItem = nil
        toggleButton = nil

        NSLog("AppDelegate: Control Strip item removed")
    }

    // MARK: - Trackpad Control

    private func setupTrackpadStateCallback() {
        TrackpadController.shared.onStateChange = { [weak self] isEnabled in
            self?.updateButtonIcon(trackpadEnabled: isEnabled)
        }
    }

    @objc private func toggleTrackpad() {
        TrackpadController.shared.toggle()
    }

    private func updateButtonIcon(trackpadEnabled: Bool) {
        let imageName = trackpadEnabled ? "trackpad_on" : "trackpad_off"

        // Update Touch Bar button
        if let image = NSImage(named: imageName) {
            toggleButton?.image = image
        }

        // Update status bar icon
        if let button = statusItem?.button {
            button.image = NSImage(named: imageName)
            if trackpadEnabled {
                button.image?.isTemplate = true
            }
        }

        NSLog("AppDelegate: Updated icon to \(imageName)")
    }
}
