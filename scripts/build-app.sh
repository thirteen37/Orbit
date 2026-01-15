#!/bin/bash
set -e

APP_NAME="Orbit"
BUNDLE_ID="com.orbit.Orbit"
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"

# Sparkle update configuration
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://thirteen37.github.io/Orbit/appcast.xml}"
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"  # Set via environment variable

# Get version from git tag
# If HEAD is exactly on a tag: use tag (e.g., "1.0.0")
# Otherwise: use last tag + "-dev" suffix (e.g., "1.0.0-dev")
TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
if git describe --tags --exact-match HEAD >/dev/null 2>&1; then
    VERSION=$TAG
else
    VERSION="${TAG}-dev"
fi

# Build number (strip v prefix and replace - with .)
BUILD_NUMBER=$(echo "$VERSION" | sed 's/^v//' | sed 's/-dev/.0/' | tr -cd '0-9.')
if [ -z "$BUILD_NUMBER" ]; then
    BUILD_NUMBER="1"
fi

echo "Version: ${VERSION}"
echo "Build number: ${BUILD_NUMBER}"

echo "Building release..."
swift build -c release

echo "Creating app bundle..."
rm -rf "build"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/"

# Create Info.plist
cat > "${APP_DIR}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Orbit</string>
    <key>CFBundleIdentifier</key>
    <string>com.orbit.Orbit</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Orbit</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Yu-Xi Lim. All rights reserved.</string>
    <key>SUFeedURL</key>
    <string>${SPARKLE_FEED_URL}</string>
EOF

# Add Sparkle public key if provided
if [ -n "$SPARKLE_PUBLIC_KEY" ]; then
    cat >> "${APP_DIR}/Contents/Info.plist" << EOF
    <key>SUPublicEDKey</key>
    <string>${SPARKLE_PUBLIC_KEY}</string>
EOF
fi

# Close the plist
cat >> "${APP_DIR}/Contents/Info.plist" << EOF
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# Copy app icon if it exists
ICON_PATH="Resources/AppIcon.icns"
if [ -f "$ICON_PATH" ]; then
    echo "Copying app icon..."
    cp "$ICON_PATH" "${APP_DIR}/Contents/Resources/"
fi

# Copy menubar icon if it exists
if [ -f "Resources/menubar-icon.png" ]; then
    echo "Copying menubar icon..."
    cp Resources/menubar-icon*.png "${APP_DIR}/Contents/Resources/"
fi

echo ""
echo "Done! App bundle created at: ${APP_DIR}"
echo ""
echo "To install:"
echo "  cp -r ${APP_DIR} /Applications/"
echo ""
echo "To run:"
echo "  open ${APP_DIR}"
