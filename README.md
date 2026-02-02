# trackpadToggle

A macOS menu bar app that puts a toggle button on the Touch Bar Control Strip to enable/disable the built-in trackpad.

## Requirements

- macOS 12.0 (Monterey) or later
- MacBook Pro with Touch Bar (2016-2019 models)
- Xcode 15.0 or later (for building)

## Features

- Touch Bar Control Strip button for quick trackpad toggle
- Icon-only interface (no text)
- Menu bar status indicator with quit option
- Runs as a background app (no dock icon)
- Survives sleep/wake cycles

## Building

### Using the build script

```bash
cd trackpadToggle
./build.sh
```

Options:
- `--debug` - Build debug configuration
- `--clean` - Clean before building
- `--install` - Install to /Applications after building

### Using Xcode

1. Open `trackpadToggle.xcodeproj` in Xcode
2. Select the `trackpadToggle` scheme
3. Build (⌘B) or Run (⌘R)

### Manual build with xcodebuild

```bash
xcodebuild -project trackpadToggle.xcodeproj -scheme trackpadToggle -configuration Release build
```

## Installation

After building, copy `trackpadToggle.app` to `/Applications`:

```bash
./build.sh --install
```

Or manually:

```bash
cp -R build/Build/Products/Release/trackpadToggle.app /Applications/
```

## Usage

1. Launch the app:
   ```bash
   open /Applications/trackpadToggle.app
   ```

2. Grant Accessibility permission when prompted, or manually in:
   - System Settings > Privacy & Security > Accessibility
   - Add trackpadToggle to the list

3. The toggle button will appear in the Touch Bar Control Strip (the right-most always-visible section)

4. Tap the button to toggle the trackpad:
   - White trackpad icon = enabled
   - Dimmed gray icon with red border = disabled

5. To quit, click the menu bar icon and select "Quit trackpadToggle"

## How It Works

### Touch Bar Integration

The app uses private DFRFoundation APIs to add a button to the Control Strip. These APIs are:
- `DFRElementSetControlStripPresenceForIdentifier` - Register/unregister the Control Strip item
- `NSTouchBarItem.addSystemTrayItem` - Add item to system tray
- `DFRSystemModalShowsCloseBoxWhenFrontMost` - Configure modal behavior

### Trackpad Disable Method

The app uses CGEventTap to intercept and block trackpad events at the Core Graphics level. This approach:
- Does not require admin/root privileges (only Accessibility permission)
- Is fully reversible
- Survives sleep/wake cycles (with automatic re-enable on timeout)
- Works on all recent macOS versions
- Distinguishes trackpad from external mouse using event characteristics

When the trackpad is "disabled", a CGEventTap intercepts pointer events and filters them:
- **Trackpad events** (continuous scroll, pressure-sensitive, gesture phases) are blocked
- **External mouse events** (discrete scroll, no pressure) pass through normally

The detection uses multiple heuristics: scroll phase/momentum (trackpad-only), continuous vs discrete scrolling, pressure sensitivity, and event subtypes.

## Troubleshooting

### Touch Bar button not appearing

1. Ensure Touch Bar is set to show "App Controls with Control Strip" in System Settings > Keyboard > Touch Bar Settings
2. Restart the app
3. Try logging out and back in

### Trackpad not being disabled

1. Check that Accessibility permission is granted in System Settings
2. Check Console.app for log messages from trackpadToggle
3. Ensure no other apps are blocking the event tap

### App crashes on launch

1. Ensure you're running macOS 12.0 or later
2. Check that the app is properly code-signed (or allow unsigned apps in Security settings for development)

## Known Limitations

- **Private API fragility**: Uses private DFRFoundation APIs for Touch Bar Control Strip integration. These have no stability guarantee and may break with macOS updates. Monitor after system updates.
- **Event filtering heuristics**: Trackpad vs mouse detection relies on event characteristics (scroll phases, pressure, etc.) which may not be 100% accurate for all devices
- **Not Mac App Store compatible**: Private API usage prevents App Store distribution
- **Single Control Strip item**: Only one item per app is supported by the private APIs
- **Accessibility permission required**: The app needs Accessibility access to create event taps

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Technical Details

### Project Structure

```
trackpadToggle/
├── trackpadToggle.xcodeproj/
│   └── project.pbxproj
├── trackpadToggle/
│   ├── AppDelegate.swift         # Main app delegate with Touch Bar setup
│   ├── TrackpadController.swift  # CGEventTap-based trackpad control
│   ├── PrivateTouchBar.h         # Bridging header for private APIs
│   ├── Info.plist                # App configuration (LSUIElement=true)
│   ├── trackpadToggle.entitlements
│   └── Assets.xcassets/
│       ├── trackpad_on.imageset/
│       └── trackpad_off.imageset/
├── build.sh                      # Terminal build script
├── README.md
└── LICENSE
```

### Private API References

- [DFRFoundation headers](https://github.com/w0lfschild/macOS_headers/tree/master/macOS/PrivateFrameworks/DFRFoundation)
- [touch-baer](https://github.com/a2/touch-baer) - Swift Touch Bar Control Strip example
- [TouchBarKit](https://github.com/L1cardo/TouchBarKit) - Swift library for Control Strip

### CGEventTap Documentation

- [CGEvent Reference](https://developer.apple.com/documentation/coregraphics/cgevent)
- [Event Taps](https://developer.apple.com/documentation/coregraphics/quartz_event_services)
