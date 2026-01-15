#!/usr/bin/env python3
"""
Update appcast.xml for Sparkle auto-updates.

This script creates or updates the appcast feed with a new release entry.
It's designed to be run from GitHub Actions after building and signing a release.

Usage:
    python3 update-appcast.py \
        --version "1.0.0" \
        --signature "SIGNATURE_STRING" \
        --url "https://github.com/user/repo/releases/download/v1.0.0/App.zip" \
        --length 12345678 \
        [--min-system-version "14.0"] \
        [--release-notes "Release notes text or URL"]
"""

import argparse
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
import xml.etree.ElementTree as ET
from xml.dom import minidom

# Sparkle XML namespace
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
DC_NS = "http://purl.org/dc/elements/1.1/"

ET.register_namespace("sparkle", SPARKLE_NS)
ET.register_namespace("dc", DC_NS)


def create_appcast_template() -> str:
    """Create a new empty appcast XML template."""
    return """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Orbit Updates</title>
        <link>https://github.com/thirteen37/Orbit</link>
        <description>Most recent updates to Orbit</description>
        <language>en</language>
    </channel>
</rss>
"""


def prettify_xml(elem: ET.Element) -> str:
    """Return a pretty-printed XML string."""
    rough_string = ET.tostring(elem, encoding="unicode")
    reparsed = minidom.parseString(rough_string)
    # Remove extra whitespace and format nicely
    pretty = reparsed.toprettyxml(indent="    ")
    # Remove the XML declaration added by minidom (we'll add our own)
    lines = pretty.split("\n")
    if lines[0].startswith("<?xml"):
        lines = lines[1:]
    # Remove empty lines
    lines = [line for line in lines if line.strip()]
    return '<?xml version="1.0" encoding="utf-8"?>\n' + "\n".join(lines)


def parse_appcast(appcast_path: Path) -> ET.Element:
    """Parse existing appcast or create new one."""
    if appcast_path.exists():
        tree = ET.parse(appcast_path)
        return tree.getroot()
    else:
        return ET.fromstring(create_appcast_template())


def create_item(
    version: str,
    signature: str,
    url: str,
    length: int,
    min_system_version: str = "14.0",
    release_notes: str | None = None,
) -> ET.Element:
    """Create a new item element for the appcast."""
    item = ET.Element("item")

    # Title
    title = ET.SubElement(item, "title")
    title.text = f"Version {version}"

    # Publication date (RFC 2822 format)
    pub_date = ET.SubElement(item, "pubDate")
    pub_date.text = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S %z")

    # Release notes (optional)
    if release_notes:
        if release_notes.startswith("http"):
            # URL to release notes
            rn_link = ET.SubElement(item, f"{{{SPARKLE_NS}}}releaseNotesLink")
            rn_link.text = release_notes
        else:
            # Inline release notes
            description = ET.SubElement(item, "description")
            description.text = release_notes

    # Enclosure (the actual download)
    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", url)
    enclosure.set("length", str(length))
    enclosure.set("type", "application/octet-stream")
    enclosure.set(f"{{{SPARKLE_NS}}}version", version)
    enclosure.set(f"{{{SPARKLE_NS}}}shortVersionString", version)
    enclosure.set(f"{{{SPARKLE_NS}}}edSignature", signature)

    # Minimum system version
    min_ver = ET.SubElement(item, f"{{{SPARKLE_NS}}}minimumSystemVersion")
    min_ver.text = min_system_version

    return item


def update_appcast(
    appcast_path: Path,
    version: str,
    signature: str,
    url: str,
    length: int,
    min_system_version: str = "14.0",
    release_notes: str | None = None,
    max_items: int = 10,
) -> None:
    """Update the appcast with a new release."""
    root = parse_appcast(appcast_path)

    # Find the channel element
    channel = root.find("channel")
    if channel is None:
        print("Error: Invalid appcast format - no channel element", file=sys.stderr)
        sys.exit(1)

    # Check if this version already exists
    for item in channel.findall("item"):
        enclosure = item.find("enclosure")
        if enclosure is not None:
            existing_version = enclosure.get(f"{{{SPARKLE_NS}}}version")
            if existing_version == version:
                print(f"Version {version} already exists in appcast, updating...")
                channel.remove(item)
                break

    # Create new item
    new_item = create_item(
        version=version,
        signature=signature,
        url=url,
        length=length,
        min_system_version=min_system_version,
        release_notes=release_notes,
    )

    # Insert at the beginning (after channel metadata)
    # Find the position after the last non-item element
    insert_pos = 0
    for i, child in enumerate(channel):
        if child.tag == "item":
            insert_pos = i
            break
        insert_pos = i + 1

    channel.insert(insert_pos, new_item)

    # Limit the number of items
    items = channel.findall("item")
    if len(items) > max_items:
        for item in items[max_items:]:
            channel.remove(item)

    # Write the updated appcast
    appcast_path.parent.mkdir(parents=True, exist_ok=True)
    with open(appcast_path, "w", encoding="utf-8") as f:
        f.write(prettify_xml(root))

    print(f"Updated appcast at {appcast_path}")
    print(f"  Version: {version}")
    print(f"  URL: {url}")


def main():
    parser = argparse.ArgumentParser(
        description="Update Sparkle appcast.xml with a new release"
    )
    parser.add_argument(
        "--version", "-v", required=True, help="Version string (e.g., 1.0.0)"
    )
    parser.add_argument(
        "--signature",
        "-s",
        required=True,
        help="EdDSA signature from sign_update tool",
    )
    parser.add_argument(
        "--url", "-u", required=True, help="Download URL for the release archive"
    )
    parser.add_argument(
        "--length", "-l", type=int, required=True, help="File size in bytes"
    )
    parser.add_argument(
        "--min-system-version",
        default="14.0",
        help="Minimum macOS version (default: 14.0)",
    )
    parser.add_argument(
        "--release-notes",
        help="Release notes text or URL to release notes page",
    )
    parser.add_argument(
        "--appcast",
        default="docs/appcast.xml",
        help="Path to appcast.xml (default: docs/appcast.xml)",
    )
    parser.add_argument(
        "--max-items",
        type=int,
        default=10,
        help="Maximum number of releases to keep (default: 10)",
    )

    args = parser.parse_args()

    update_appcast(
        appcast_path=Path(args.appcast),
        version=args.version,
        signature=args.signature,
        url=args.url,
        length=args.length,
        min_system_version=args.min_system_version,
        release_notes=args.release_notes,
        max_items=args.max_items,
    )


if __name__ == "__main__":
    main()
