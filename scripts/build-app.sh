#!/bin/bash
set -e

APP_NAME="Orbit"
BUNDLE_ID="com.orbit.Orbit"
VERSION="1.0"
BUILD_DIR=".build/release"
APP_DIR="build/${APP_NAME}.app"

echo "Building release..."
swift build -c release

echo "Creating app bundle..."
rm -rf "build"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/"

# Create Info.plist
cat > "${APP_DIR}/Contents/Info.plist" << 'EOF'
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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Lim Yu-Xi. All rights reserved.</string>
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
