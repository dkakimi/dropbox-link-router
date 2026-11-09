#!/bin/zsh
# .app バンドルを組み立てる。 --install で ~/Applications にコピーする。
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Dropbox Link Router"
APP="build/${APP_NAME}.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/DropboxLinkRouter"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/DropboxLinkRouter"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# 個人利用なのでアドホック署名
codesign --force --sign - "$APP"
echo "built: $APP"

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/"${APP_NAME}.app"
  cp -R "$APP" ~/Applications/
  echo "installed: ~/Applications/${APP_NAME}.app"
fi
