#!/bin/bash

# Enso App Packaging Script
# Builds the app and creates a DMG for distribution

set -e

# Configuration
APP_NAME="Enso"
SCHEME="Enso"
PROJECT="Enso.xcodeproj"
CONFIGURATION="Release"
BUILD_DIR="build"
DMG_DIR="dist"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Clean previous builds
log_info "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$DMG_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$DMG_DIR"

# Build the app
log_info "Building $APP_NAME for Release..."
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -destination "generic/platform=macOS" \
    clean build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | grep -E "^(Build|Compile|Link|Sign|error:|warning:)" || true

# Check if build succeeded
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    log_error "Build failed. App not found at $APP_PATH"
    exit 1
fi

log_info "Build successful!"

# Create DMG staging directory
STAGING_DIR="$BUILD_DIR/dmg-staging"
mkdir -p "$STAGING_DIR"

# Copy app to staging
log_info "Preparing DMG contents..."
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create Applications symlink
ln -s /Applications "$STAGING_DIR/Applications"

# Get version from Info.plist if available
VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
BUILD_NUMBER=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "1")

DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="$DMG_DIR/$DMG_NAME"

log_info "Creating DMG: $DMG_NAME..."

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up staging
rm -rf "$STAGING_DIR"

# Calculate file size
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

log_info "Successfully created $DMG_PATH ($DMG_SIZE)"
log_info "Version: $VERSION (Build $BUILD_NUMBER)"

# Open the dist folder
open "$DMG_DIR"

echo ""
log_info "Done! Your DMG is ready for distribution."
