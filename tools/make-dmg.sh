#!/usr/bin/env bash
# 打一个「拖进 Applications 就能装」的 DMG：左边应用、右边「应用程序」，背景画箭头与安装提示
#
# 用法：tools/make-dmg.sh <App.app> <输出.dmg> [背景.tiff] [卷图标.icns]
#   背景缺省时按应用名现场生成（tools/make-dmg-background.py，深色底）
#   卷图标缺省取 App 内 Contents/Resources/AppIcon.icns
# 首次运行会请求控制 Finder 的权限（用于排版窗口）
set -euo pipefail

APP_PATH="${1:?用法: make-dmg.sh <App.app> <输出.dmg> [背景.tiff] [卷图标.icns]}"
OUT="${2:?用法: make-dmg.sh <App.app> <输出.dmg> [背景.tiff] [卷图标.icns]}"
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -d "$APP_PATH" ] || { echo "缺少 $APP_PATH"; exit 1; }
NAME="$(basename "$APP_PATH" .app)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
ICON="${4:-$APP_PATH/Contents/Resources/AppIcon.icns}"
VOL="$NAME $VERSION"
STAGE="$(mktemp -d)"
RW="$(mktemp -u).dmg"
trap 'hdiutil detach "/Volumes/$VOL" -quiet 2>/dev/null || true; rm -rf "$STAGE" "$RW"' EXIT

BG="${3:-}"
if [ -z "$BG" ]; then
  BG="$STAGE.bg.tiff"
  python3 "$HERE/make-dmg-background.py" "$NAME" "$BG" >/dev/null
fi

echo "==> 准备挂载内容"
cp -R "$APP_PATH" "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"
mkdir "$STAGE/.background" && cp "$BG" "$STAGE/.background/background.tiff"

# 同名卷会让新卷挂成「… 1」，Finder 排版落到错的卷上
for v in "/Volumes/$VOL"*; do [ -d "$v" ] && hdiutil detach "$v" -force -quiet || true; done
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDRW -quiet "$RW"
MNT="$(hdiutil attach "$RW" -noautoopen | grep -o '/Volumes/.*$' | tail -1)"
[ "$MNT" = "/Volumes/$VOL" ] || { echo "!! 卷挂载在 $MNT，不是 /Volumes/$VOL"; exit 1; }
layout() {
osascript <<OSA
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 520}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "$NAME.app" of container window to {170, 190}
    set position of item "Applications" of container window to {490, 190}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
OSA
}
# Finder 偶尔不写背景图书签（.DS_Store 缺 pBBk），装出来是白底；写进去为止，最多 3 次
echo "==> 排版 Finder 窗口"
for i in 1 2 3; do
  sleep 2
  layout || true; sync; sleep 1
  LC_ALL=C grep -aq pBBk "/Volumes/$VOL/.DS_Store" 2>/dev/null && break
  [ "$i" = 3 ] && { echo "!! 背景图未写入 .DS_Store"; exit 1; }
  echo "   背景未写入，重试 $i"
done
# 卷图标在排版之后写：排版期间 Finder 会清掉卷根目录的 .VolumeIcon.icns
if [ -f "$ICON" ]; then
  cp "$ICON" "/Volumes/$VOL/.VolumeIcon.icns"
  SetFile -a C "/Volumes/$VOL"
fi
sync
hdiutil detach "/Volumes/$VOL" -quiet

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
echo "==> 压缩成 DMG"
hdiutil convert "$RW" -format UDZO -quiet -o "$OUT"
rm -f "$STAGE.bg.tiff"
echo "完成：${OUT}（$(du -h "$OUT" | cut -f1 | xargs)）"
