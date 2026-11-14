#!/bin/zsh
# Builds Keytone.app (release) next to this script.
set -e
[ -d /Applications/Xcode.app ] && export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
cd "$(dirname "$0")"
swift build -c release --arch arm64 --arch x86_64
APP=Keytone.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS $APP/Contents/Resources
cp "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Keytone" $APP/Contents/MacOS/Keytone
[ -f AppIcon.icns ] && cp AppIcon.icns $APP/Contents/Resources/
[ -d Packs ] && cp -R Packs $APP/Contents/Resources/Packs
cat > $APP/Contents/Info.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Keytone</string>
  <key>CFBundleDisplayName</key><string>Keytone</string>
  <key>CFBundleIdentifier</key><string>app.keytone.mac</string>
  <key>CFBundleExecutable</key><string>Keytone</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION:-1.0.0}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST
# Stable local identity keeps macOS privacy permissions across rebuilds; falls back to ad-hoc.
ID="Keytone Local Signing"
if security find-identity -p codesigning | grep -q "$ID"; then
  codesign --force --deep -s "$ID" $APP
else
  echo "warning: '$ID' not found, signing ad-hoc (Input Monitoring must be re-granted after each build)"
  codesign --force --deep -s - $APP
fi
ditto -c -k --keepParent $APP Keytone.zip
echo "Built $(pwd)/$APP and Keytone.zip"
