#!/bin/bash
# FocusBMApp.app バンドルを作成するスクリプト
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="FocusBMApp"
BUNDLE_DIR="$PROJECT_DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

# リリースビルド
echo "Building release binary..."
cd "$PROJECT_DIR"
swift build -c release

# 既存バンドルを削除
rm -rf "$BUNDLE_DIR"

# バンドル構造を作成
mkdir -p "$MACOS_DIR"

# バイナリをコピー
cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Info.plist を作成（署名より前に配置する必要がある）
cat > "$CONTENTS_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FocusBMApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.focusbm.app</string>
    <key>CFBundleName</key>
    <string>FocusBM</string>
    <key>CFBundleDisplayName</key>
    <string>FocusBM</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>FocusBM はブックマークしたアプリやブラウザタブを復元するために AppleScript を使用します。</string>
</dict>
</plist>
PLIST

# アドホック署名（Info.plist の後に実行 → TCC がバンドルIDで識別可能に）
echo "Code signing..."
codesign --force --sign - \
  --identifier "com.focusbm.app" \
  "$BUNDLE_DIR"

echo ""
echo "✅ $APP_NAME.app を作成しました: $BUNDLE_DIR"
echo ""
echo "インストール:"
echo "  cp -r $APP_NAME.app /Applications/"
echo "  # または ~/Applications/ にコピー"
echo ""
echo "起動:"
echo "  open $APP_NAME.app"
