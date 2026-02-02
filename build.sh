#!/bin/bash
#
# trackpadToggle - Touch Bar trackpad toggle
# Copyright (C) 2026
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Build script for trackpadToggle
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="trackpadToggle"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

print_error() {
    echo -e "${RED}Error:${NC} $1"
}

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    print_error "xcodebuild not found. Please install Xcode."
    exit 1
fi

# Parse arguments
CONFIGURATION="Release"
CLEAN=false
INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            CONFIGURATION="Debug"
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --install)
            INSTALL=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --debug    Build debug configuration"
            echo "  --clean    Clean before building"
            echo "  --install  Install to /Applications after building"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

cd "$PROJECT_DIR"

# Clean if requested
if [ "$CLEAN" = true ]; then
    print_status "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" clean 2>/dev/null || true
fi

# Build
print_status "Building $APP_NAME ($CONFIGURATION)..."
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR" \
    build

# Find the built app
APP_PATH=$(find "$BUILD_DIR" -name "$APP_NAME.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    print_error "Build failed - $APP_NAME.app not found"
    exit 1
fi

print_status "Build successful: $APP_PATH"

# Install if requested
if [ "$INSTALL" = true ]; then
    print_status "Installing to /Applications..."

    # Check if app is running and kill it
    if pgrep -x "$APP_NAME" > /dev/null; then
        print_warning "Killing running instance of $APP_NAME..."
        pkill -x "$APP_NAME" || true
        sleep 1
    fi

    # Remove old installation
    if [ -d "/Applications/$APP_NAME.app" ]; then
        print_status "Removing old installation..."
        rm -rf "/Applications/$APP_NAME.app"
    fi

    # Copy new app
    cp -R "$APP_PATH" /Applications/
    print_status "Installed to /Applications/$APP_NAME.app"

    # Prompt to launch
    echo ""
    print_status "To launch, run:"
    echo "    open /Applications/$APP_NAME.app"
    echo ""
    print_warning "You will need to grant Accessibility permission in:"
    echo "    System Settings > Privacy & Security > Accessibility"
fi

echo ""
print_status "Done!"
