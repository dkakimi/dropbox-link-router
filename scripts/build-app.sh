#!/bin/zsh
# .app バンドルを組み立てる（Apple Silicon / Intel 両対応）。
#   --install  ~/Applications にコピーする
#   --zip      配布用の zip を build/ に作る
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Dropbox Link Router"
APP="build/${APP_NAME}.app"
ARCHS=(--arch arm64 --arch x86_64)

swift build -c release $ARCHS
BIN="$(swift build -c release $ARCHS --show-bin-path)/DropboxLinkRouter"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/DropboxLinkRouter"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# 個人利用なのでアドホック署名
codesign --force --sign - "$APP"
echo "built: $APP"

for arg in "$@"; do
  case "$arg" in
    --install)
      mkdir -p ~/Applications
      rm -rf ~/Applications/"${APP_NAME}.app"
      cp -R "$APP" ~/Applications/
      echo "installed: ~/Applications/${APP_NAME}.app"
      ;;
    --zip)
      ZIP="build/Dropbox-Link-Router.zip"
      rm -f "$ZIP"
      ditto -c -k --keepParent "$APP" "$ZIP"
      echo "zipped: $ZIP"
      ;;
  esac
done
