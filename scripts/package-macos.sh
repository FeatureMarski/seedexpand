#!/bin/sh
# Run by the coordinator under the resource gate. Never launches or installs the app.
set -eu
cd "$(dirname "$0")/.."
[ "$(uname -s)" = Darwin ] || { echo 'macOS is required' >&2; exit 1; }
swift build -c release --jobs 1 --product SeedExpandApp
bin="$(swift build -c release --show-bin-path)"
app=dist/SeedExpand.app
mkdir -p "$app/Contents/MacOS"
cp "$bin/SeedExpandApp" "$app/Contents/MacOS/SeedExpandApp"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>SeedExpandApp</string>
<key>CFBundleIdentifier</key><string>org.seedexpand.app</string>
<key>CFBundleName</key><string>SeedExpand</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
plutil -lint "$app/Contents/Info.plist"
printf 'Unsigned development app: %s\n' "$app"
