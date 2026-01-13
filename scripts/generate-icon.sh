#!/bin/bash
# Generate AppIcon.icns from the SVG source
# Requires: rsvg-convert (brew install librsvg) or will fall back to sips

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SVG_SOURCE="${PROJECT_DIR}/appicon-draft-v1.svg"
ICONSET_DIR="${PROJECT_DIR}/build/AppIcon.iconset"
OUTPUT_ICNS="${PROJECT_DIR}/Resources/AppIcon.icns"

# Required icon sizes for macOS app icons
SIZES=(16 32 128 256 512)

echo "Generating app icon from: ${SVG_SOURCE}"

# Create directories
mkdir -p "${ICONSET_DIR}"
mkdir -p "${PROJECT_DIR}/Resources"

# Check for rsvg-convert (preferred)
if command -v rsvg-convert &> /dev/null; then
    echo "Using rsvg-convert..."
    for size in "${SIZES[@]}"; do
        # Standard resolution
        rsvg-convert -w "$size" -h "$size" "$SVG_SOURCE" -o "${ICONSET_DIR}/icon_${size}x${size}.png"
        # Retina (@2x)
        size2x=$((size * 2))
        rsvg-convert -w "$size2x" -h "$size2x" "$SVG_SOURCE" -o "${ICONSET_DIR}/icon_${size}x${size}@2x.png"
    done
else
    echo "rsvg-convert not found. Install with: brew install librsvg"
    echo ""
    echo "Alternative: Convert the SVG manually using Preview or an online tool."
    echo "Create these PNG files in ${ICONSET_DIR}:"
    for size in "${SIZES[@]}"; do
        echo "  - icon_${size}x${size}.png (${size}x${size} pixels)"
        echo "  - icon_${size}x${size}@2x.png ($((size * 2))x$((size * 2)) pixels)"
    done
    exit 1
fi

# Generate .icns using iconutil
echo "Creating .icns file..."
iconutil -c icns "${ICONSET_DIR}" -o "${OUTPUT_ICNS}"

# Clean up iconset
rm -rf "${ICONSET_DIR}"

echo "Done! Icon created at: ${OUTPUT_ICNS}"
