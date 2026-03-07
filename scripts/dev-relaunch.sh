#!/bin/bash
# FocusBM を終了・アクセシビリティリセット・再ビルド・再起動するスクリプト
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_BUNDLE="$PROJECT_DIR/FocusBMApp.app"
BUNDLE_ID="com.focusbm.app"

# 1. 既存プロセスを終了
echo "Quitting existing FocusBM instances..."
pkill -x FocusBMApp || true

# 少し待ってプロセスが完全に終了するのを待つ
sleep 0.5

# 2. アクセシビリティ権限をリセット
echo "Resetting Accessibility permission for $BUNDLE_ID..."
tccutil reset Accessibility "$BUNDLE_ID" || true

# 3. バンドル再ビルド
echo "Rebuilding app bundle..."
bash "$SCRIPT_DIR/bundle.sh"

# 4. 再起動
echo "Launching $APP_BUNDLE..."
open "$APP_BUNDLE"

echo ""
echo "✅ Relaunched FocusBM"
echo "If macOS asks again, re-enable Accessibility for FocusBM."
