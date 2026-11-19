#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
BUILD_DIR="${TMPDIR%/}/InnerCorners-GE-release-build"
APP_NAME="InnerCorners GE.app"
APP_DIR="$BUILD_DIR/$APP_NAME"
RESOURCE_DIR="$APP_DIR/Contents/Resources"
ICON_BUILD_DIR="$BUILD_DIR/generated-icons"
VERIFY_DIR="$BUILD_DIR/verify"
OUTPUT_ZIP="$PROJECT_DIR/outputs/InnerCorners-GE-v0.12.0-build70-arm64.app.zip"
CACHE_DIR="$BUILD_DIR/clang-cache"

rm -rf "$BUILD_DIR" "$PROJECT_DIR/work/clang-cache"
mkdir -p "$APP_DIR/Contents/MacOS" "$RESOURCE_DIR" "$CACHE_DIR" "$PROJECT_DIR/outputs"

CLANG_MODULE_CACHE_PATH="$CACHE_DIR" swiftc \
  -swift-version 6 \
  -warnings-as-errors \
  "$PROJECT_DIR/Scripts/generate_icons.swift" \
  -o "$BUILD_DIR/generate_icons"

"$BUILD_DIR/generate_icons" \
  "$PROJECT_DIR/Assets/ic_icon.png" \
  "$PROJECT_DIR/Assets/ic_menu_icon.png" \
  "$ICON_BUILD_DIR"

cp "$ICON_BUILD_DIR/AppIcon.icns" "$RESOURCE_DIR/AppIcon.icns"
cp "$ICON_BUILD_DIR/MenuBarIcon.png" "$RESOURCE_DIR/MenuBarIcon.png"
cp "$ICON_BUILD_DIR/MenuBarIcon@2x.png" "$RESOURCE_DIR/MenuBarIcon@2x.png"

CLANG_MODULE_CACHE_PATH="$CACHE_DIR" swiftc \
  -swift-version 6 \
  -warnings-as-errors \
  -O \
  -parse-as-library \
  -target arm64-apple-macosx14.0 \
  "$PROJECT_DIR"/Sources/InnerCorners/*.swift \
  -o "$APP_DIR/Contents/MacOS/InnerCorners"

cp "$PROJECT_DIR/Packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$OUTPUT_ZIP"
(
  cd "$BUILD_DIR"
  /usr/bin/zip -q -r -X "$OUTPUT_ZIP" "$APP_NAME"
)

mkdir -p "$VERIFY_DIR"
unzip -q "$OUTPUT_ZIP" -d "$VERIFY_DIR"
if [[ -n "$(find "$VERIFY_DIR" -name '._*' -print -quit)" ]]; then
  print -u2 "AppleDouble metadata found in packaged app"
  exit 1
fi
codesign --verify --deep --strict --verbose=2 "$VERIFY_DIR/$APP_NAME"
shasum -a 256 "$OUTPUT_ZIP"
