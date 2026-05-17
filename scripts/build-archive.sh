#!/bin/bash
set -e

# TheClapper v2 — App Store Archive Build
# Requires: DEVELOPMENT_TEAM set in project.pbxproj or via env var

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="TheClapper"
BUNDLE_ID="com.edgeless.theclapper"
ARCHIVE_PATH="$PROJECT_DIR/build/TheClapper.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/Export"

# If DEVELOPMENT_TEAM is passed as env var, inject it via xcconfig
if [ -n "$DEVELOPMENT_TEAM" ]; then
  XCCONFIG="$PROJECT_DIR/build/temp-signing.xcconfig"
  mkdir -p "$PROJECT_DIR/build"
  echo "DEVELOPMENT_TEAM = $DEVELOPMENT_TEAM" > "$XCCONFIG"
  XCCONFIG_FLAG="-xcconfig \"$XCCONFIG\""
else
  XCCONFIG_FLAG=""
fi

echo "→ Cleaning..."
xcodebuild clean -project "$PROJECT_DIR/TheClapper.xcodeproj" -scheme "$SCHEME" $XCCONFIG_FLAG

echo "→ Archiving..."
xcodebuild archive \
  -project "$PROJECT_DIR/TheClapper.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  $XCCONFIG_FLAG \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates

echo "→ Exporting IPA..."
cat > "$PROJECT_DIR/build/ExportOptions.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>destination</key>
  <string>export</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>uploadBitcode</key>
  <false/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$PROJECT_DIR/build/ExportOptions.plist" \
  -allowProvisioningUpdates

echo ""
echo "✅ IPA exported to: $EXPORT_PATH"
ls -lh "$EXPORT_PATH"/*.ipa