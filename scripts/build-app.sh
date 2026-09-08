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

# Bundle Sparkle.framework.
#
# The binary links Sparkle as @rpath/Sparkle.framework/..., so the framework has
# to travel inside the bundle and the executable needs an rpath pointing at it.
# Without this the app dies at launch with "Library not loaded: @rpath/
# Sparkle.framework/Versions/B/Sparkle" before any of its own code runs.
SPARKLE_SRC="${BUILD_DIR}/Sparkle.framework"
if [ -d "$SPARKLE_SRC" ]; then
    echo "Bundling Sparkle.framework..."
    mkdir -p "${APP_DIR}/Contents/Frameworks"
    cp -R "$SPARKLE_SRC" "${APP_DIR}/Contents/Frameworks/"

    # Add the rpath only if it is not already present - install_name_tool errors
    # on a duplicate, and the binary is rebuilt fresh each run.
    if ! otool -l "${APP_DIR}/Contents/MacOS/${APP_NAME}" \
        | grep -q "@executable_path/../Frameworks"; then
        install_name_tool -add_rpath "@executable_path/../Frameworks" \
            "${APP_DIR}/Contents/MacOS/${APP_NAME}"
    fi
else
    echo "WARNING: ${SPARKLE_SRC} not found - the app will crash at launch."
    echo "         Run 'swift build -c release' first."
fi

# Code signing.
#
# Orbit needs Accessibility permission, and macOS ties that grant to the app's
# signing identity. An ad-hoc signature changes every rebuild, so the grant is
# revoked each time and has to be re-approved by hand. Signing with a stable
# identity keeps it.
#
# Override with ORBIT_SIGN_IDENTITY, or set it to "-" to force ad-hoc.
if [ -z "${ORBIT_SIGN_IDENTITY:-}" ]; then
    # Prefer Developer ID (distributable) over Apple Development (local only).
    ORBIT_SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')
    if [ -z "$ORBIT_SIGN_IDENTITY" ]; then
        ORBIT_SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
            | grep -o '"Apple Development: [^"]*"' | head -1 | tr -d '"')
    fi
fi

if [ -n "$ORBIT_SIGN_IDENTITY" ] && [ "$ORBIT_SIGN_IDENTITY" != "-" ]; then
    echo "Signing with: ${ORBIT_SIGN_IDENTITY}"
    SIGN_ARGS=(--force --timestamp=none --sign "$ORBIT_SIGN_IDENTITY")
else
    echo "No signing identity found - using ad-hoc signature."
    echo "WARNING: Accessibility permission must be re-granted after every rebuild."
    SIGN_ARGS=(--force --sign -)
fi

# Nested code first, outermost bundle last - a bundle's signature covers its
# nested code, so signing the app before the framework invalidates it.
if [ -d "${APP_DIR}/Contents/Frameworks/Sparkle.framework" ]; then
    codesign "${SIGN_ARGS[@]}" "${APP_DIR}/Contents/Frameworks/Sparkle.framework"
fi
codesign "${SIGN_ARGS[@]}" "${APP_DIR}"
codesign --verify --deep "${APP_DIR}" && echo "Signature verified."

echo ""
echo "Done! App bundle created at: ${APP_DIR}"
echo ""
echo "To install:"
echo "  cp -r ${APP_DIR} /Applications/"
echo ""
echo "To run:"
echo "  open ${APP_DIR}"
